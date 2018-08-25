from __future__ import print_function, division

import numpy as np
import random
import math
import pygame

import pycnbi.utils.cnbi_lsl as cnbi_lsl
import pylsl
import threading
import os
import sys
import ctypes
import time
from builtins import input  


ImpulseType = 1 # Must be the same as in C++

def selectForceDir(old_button,new_button):
    rand = random.choice([1,2]) #The 2 will be decoded as the negative direction (=-1)
    if (old_button == 0 and new_button == 3) or (old_button == 1 and new_button == 2) or (old_button == 2 and new_button == 1) or (old_button == 3 and new_button == 0):
        return (rand,0)

    elif (old_button == 0 and new_button == 1) or (old_button == 1 and new_button == 0) or (old_button == 2 and new_button == 3) or (old_button == 3 and new_button == 2):
        return (0,rand)

    else:
        return(0,0)


def selectForceMag(dirx,diry):
    if ImpulseType == 1:
        #randMag = random.choice([1.0,1.5,2.0,2.5,3.0,3.5,4.0]) #This line is for the MiniExperiment
        randMag = random.choice([1.0,2.0,3.0])
        return randMag
    elif ImpulseType == 2:
        randMag = random.choice([20,35,50])
        randSign = random.choice(['+','-'])
        return randSign+str(randMag) 


#mag shoud be 1,2 or 3.
#output of this function is 101(positive and small),102(pos and medium),103(pos and big),201(negative and small),202 or 203.
def selectTriggerValue(mag,dx=None,dy=None): 
    if(dx != None and dy != None):
        if(dx == 2 | dy == 2):
            trig = 200
        else:
            trig = 100
        trig = trig + mag
    else:
        if(mag < 0):
            trig = 200
        else:
            trig = 100
        if(abs(mag) == 20):
            trig = trig + 1
        elif(abs(mag) == 40):
            trig = trig + 2
        elif(abs(mag) == 60):
            trig == trig + 3
    return trig


def buildResolutionParameters(W,H,distance):
    xTop = 20#45
    xBottom = 20#47

    xSum1 = xTop
    xDiv = xTop + xBottom
    xMult = (W/2 + distance) - (W/2 - distance)
    xSum2 = W/2 - distance

    #yTop = 40 #93
    #yBottom = 45 #24
    yTop = 20
    yBottom = 20

    ySum1 = yTop
    yDiv = yTop + yBottom
    yMult = (H/2 + distance) - (H/2 - distance)
    ySum2 = H/2 - distance

    return [xSum1,xDiv,xMult,xSum2,ySum1,yDiv,yMult,ySum2]



def Robot2ScreenCoordinates(xR,yR,parameters):

    #yR = yR + 100;

    xS = int(((xR + parameters[0])/parameters[1] * parameters[2]) + parameters[3])
    #yS = int(((- yR + parameters[4])/parameters[5] *parameters[6]) + parameters[7])
    yS = int(((yR + parameters[4])/parameters[5] *parameters[6]) + parameters[7])
    return (xS,yS)


def selectDeviation(zeroProb):
    n = np.random.choice([0, 3, 5, 7],p=[zeroProb, (1-zeroProb)/3, (1-zeroProb)/3, (1-zeroProb)/3])
    if n != 0:
        const = 4 #Must be smaller than 10 because of the decoding in c++
        sign = np.random.choice(['+', '-'],p=[0.5, 0.5])
        if sign == '+':
            trig = 100 + n
        else:
            trig = 50 + n

    else:
        sign = '+' 
        trig = 99
        const = 4 #Must be smaller than 10 because of the decoding in c++


    return sign+str(n),trig,const 





class Trigger(object):
    """
    Supported device types:
     'Arduino': CNBI Arduino trigger
     'USB2LPT': Commercial USB2LPT adapter
     'DESKTOP': Desktop native LPT
     'SOFTWARE': Software trigger
     'FAKE': Mock trigger device for testing

    When using USB2LPT, the port number (e.g. 0x378) can be searched automatically.
    When using Desktop's LPT, the port number must be specified during initialization.

    Software trigger writes event information into a text file with LSL timestamps, which
    can be later added to fif. This file will be automatically saved and closed when Ctrl+C is
    pressed or terminal window is closed (or killed for whatever reason).

    The asynchronous function signal(x) sends 1-byte integer value x and returns immediately.
    It schedules to send the value 0 at the end of the signal length.

    To use with USB2LPT, download the driver from:
    https://www-user.tu-chemnitz.de/~heha/bastelecke/Rund%20um%20den%20PC/USB2LPT/index.en.htm

    I've made a C++ library to send commands to LPTx using standard Windows API.
    Use LptControl64.dll for 64 bit Python and LptControl32.dll for 32 bit Python.

    Some important functions:
    int init(duration)
        Returns False if error, True if success.
        Duration unit: msec

    void signal(value)
        Sends the value to the parallel port and sets to 0 after a set period.
        The value shuold be an integer in the range of 0-255.
    """

    def __init__(self, lpttype='USB2LPT', portaddr=None, verbose=True):
        self.evefile = None
        self.lpttype = lpttype
        self.verbose = verbose

        if self.lpttype in ['USB2LPT', 'DESKTOP']:
            if self.lpttype == 'USB2LPT':
                if ctypes.sizeof(ctypes.c_voidp) == 4:
                    dllname = 'LptControl_USB2LPT32.dll'  # 32 bit
                else:
                    dllname = 'LptControl_USB2LPT64.dll'  # 64 bit
                if portaddr not in [0x278, 0x378]:
                    self.print('Warning: LPT port address %d is unusual.' % portaddr)

            elif self.lpttype == 'DESKTOP':
                if ctypes.sizeof(ctypes.c_voidp) == 4:
                    dllname = 'LptControl_Desktop32.dll'  # 32 bit
                else:
                    dllname = 'LptControl_Desktop64.dll'  # 64 bit
                if portaddr not in [0x278, 0x378]:
                    self.print('Warning: LPT port address %d is unusual.' % portaddr)

            self.portaddr = portaddr
            search = []
            search.append(os.path.dirname(__file__) + '/' + dllname)
            search.append(os.path.dirname(__file__) + '/libs/' + dllname)
            search.append(os.getcwd() + '/' + dllname)
            search.append(os.getcwd() + '/libs/' + dllname)
            for f in search:
                if os.path.exists(f):
                    dllpath = f
                    break
            else:
                self.print('ERROR: Cannot find the required library %s' % dllname)
                raise RuntimeError

            self.print('Loading %s' % dllpath)
            self.lpt = ctypes.cdll.LoadLibrary(dllpath)

        elif self.lpttype == 'ARDUINO':
            import serial, serial.tools.list_ports
            BAUD_RATE = 115200

            # portaddr should be None or in the form of 'COM1', 'COM2', etc.
            if portaddr is None:
                arduinos = [x for x in serial.tools.list_ports.grep('Arduino')]
                if len(arduinos) == 0:
                    print('No Arduino found. Stop.')
                    sys.exit()

                for i, a in enumerate(arduinos):
                    print('Found %s' % a)
                com_port = arduinos[0].device
            else:
                com_port = portaddr

            self.ser = serial.Serial(com_port, BAUD_RATE)
            time.sleep(1)  # doesn't work without this delay. why?
            print('Connected to %s.' % com_port)
            if com_port[:3] != 'COM':
                self.print('Warning: COM port %d is unusual.' % portaddr)

        elif self.lpttype == 'SOFTWARE':
            self.print('Using software trigger')
            # get data file location
            LSL_SERVER = 'StreamRecorderInfo'
            inlet = cnbi_lsl.start_client(LSL_SERVER)
            fname = inlet.info().source_id()
            if fname[-4:] != '.pcl':
                self.print('ERROR: Received wrong record file name format %s' % fname)
                sys.exit(-1)
            evefile = fname[:-8] + '-eve.txt'
            self.print('Event file is: %s' % evefile)
            self.evefile = open(evefile, 'a')  # unbuffered writing

        elif self.lpttype == 'FAKE' or self.lpttype is None or self.lpttype is False:
            self.print('WARNING: Using a fake trigger.')
            self.lpttype = 'FAKE'
            self.lpt = None

        else:
            self.print('ERROR: Unknown LPT port type %s' % lpttype)
            sys.exit(-1)

    def __del__(self):
        if self.evefile is not None and not self.evefile.closed:
            self.evefile.close()
            self.print('Event file saved.')
            sys.stdout.flush()

    def print(self, *args):
        print('[pyLptControl] ', end='')
        print(*args)

    def init(self, duration):
        if self.lpttype == 'SOFTWARE':
            self.print('>> Ignoring delay parameter for software trigger')
            return True
        elif self.lpttype == 'FAKE':
            return True
        else:
            self.delay = duration / 1000.0

            if self.lpttype in ['DESKTOP', 'USB2LPT']:
                if self.lpt.init() == -1:
                    self.print('Connecting to LPT port failed. Check the driver status.')
                    self.lpt = None
                    return False

            self.action = False
            self.offtimer = threading.Timer(self.delay, self.signal_off)
            return True

    # write to software trigger
    def write_event(self, value):
        assert self.lpttype == 'SOFTWARE'
        self.evefile.write('%.6f\t0\t%d\n' % (pylsl.local_clock(), value))
        return True

    # set data
    def set_data(self, value):
        if self.lpttype == 'SOFTWARE':
            self.print('>> set_data() not supported for software trigger.')
            return False
        elif self.lpttype == 'FAKE':
            self.print('FAKE trigger value', value)
            return True
        else:
            if self.lpttype == 'USB2LPT':
                self.lpt.setdata(value)
            elif self.lpttype == 'DESKTOP':
                self.lpt.setdata(self.portaddr, value)
            elif self.lpttype == 'ARDUINO':
                self.ser.write(chr(value))
            else:
                raise RuntimeError('Wrong trigger device')

    # sends data and turn off after delay
    def signal(self, value):
        if self.lpttype == 'SOFTWARE':
            if self.verbose is True:
                self.print('Sending software trigger', value)
            return self.write_event(value)
        elif self.lpttype == 'FAKE':
            self.print('Sending FAKE trigger signal', value)
            return True
        else:
            if self.offtimer.is_alive():
                self.print('Warning: You are sending a new signal before the end of the last signal. Signal ignored.')
                self.print('self.delay=%.1f' % self.delay)
                return False
            self.set_data(value)
            if self.verbose is True:
                #self.print('Sending', value)
                pass
            self.offtimer.start()
            return True

    # set data to zero (all bits off)
    def signal_off(self):
        if self.lpttype == 'SOFTWARE':
            return self.write_event(0)
        elif self.lpttype == 'FAKE':
            self.print('FAKE trigger off')
            return True
        else:
            self.set_data(0)
            self.offtimer = threading.Timer(self.delay, self.signal_off)

    # set pin
    def set_pin(self, pin):
        if self.lpttype == 'SOFTWARE':
            self.print('>> set_pin() not supported for software trigger.')
            return False
        elif self.lpttype == 'FAKE':
            self.print('FAKE trigger pin', pin)
            return True
        else:
            self.set_data(2 ** (pin - 1))



def getStartEndFrames(mouse,numberTrials):
    startF = np.zeros((numberTrials+1,1))
    count = 0
    for f in range(0,mouse.shape[0]):
        if np.all(mouse[f] == [0,0,0,0]):
            startF[count] = f
            count = count + 1
    endF = startF - 1
    endF = endF[1:]
    endF = endF.astype(int)
    startF = startF + 1
    startF = startF.astype(int)
    return startF,endF