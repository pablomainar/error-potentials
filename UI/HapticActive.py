
#/usr/bin/env python

# Import modules:
import os, pygame
from random import randint, sample, choice
from pygame.locals import *
import numpy as np
from numpy import loadtxt, savetxt, deg2rad, array, eye, cos, sin, dot, add, subtract
from Tkinter import *
import socket
from utilitiesActive import *

# Variables: Normally only need to change the IP adress
number_trials = 250 #Number of trials
HOST, PORT = "128.179.177.159",27015 #IP adress of this computer (to communicate with the robot ccontroler process)
delta = -50 #Position of the wall. Must be the same as in C++
waitingTime = 3000 #Time before subject can start the movement, in ms
probZero = 0.65 #Probablity of not having any perturbation
distance = 125 #This sets distances between buttons
TimeToClick = 1000 #Time that the user has to be inside the target to make a click, in ms


# Variables initialization (do not touch)
W_res = 0
H_res = 0
sent98 = False

# Connect with the other process, that should be listening for connections
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect((HOST, PORT))

# Define pyame events
ARMMOTION = pygame.USEREVENT + 1
ARMPRESSED = pygame.USEREVENT + 2
ARMRELEASED = pygame.USEREVENT + 3



# Functions used to load media:
def load_image(filename, colorkey=None):
    fullname = os.path.join('C:\Users\Pablo\Documents\Universidad\MasterProject\Python\media\grandes',filename)
    try:
        image = pygame.image.load(fullname)
    except pygame.error, message:
        print 'Cannot load image:', fullname
        raise SystemExit, message
    image = image.convert_alpha()
    if colorkey is not None:
        if colorkey is -1:
            colorkey = image.get_at((0,0))
        image.set_colorkey(colorkey, RLEACCEL)
    return image

def load_sound(filename):
    class NoneSound:
        def play(self): pass
    if not pygame.mixer or not pygame.mixer.get_init():
        return NoneSound()
    fullname = os.path.join('C:\Users\Pablo\Documents\Universidad\MasterProject\Python\media',filename)
    try:
        sound = pygame.mixer.Sound(fullname)
    except pygame.error, message:
        print 'Cannot load sound:', fullname
        raise SystemExit, message
    return sound


# Class for initial user data GUI:
class SessionInfoDlg(Frame):
    def get_input_text(self):
        global sessionInfo
        sessionInfo = self.sessionInfo.get('1.0','1.end')
        self.quit()

    def createWidgets(self):

        self.sessionInfo = Text(self, height=1, padx=3, pady=3, width=16)
        self.sessionInfo.pack({"side": "top"})

        self.OK = Button(self, text='OK', fg='black', padx=3, pady=3, width=6, command=self.get_input_text)
        self.OK.pack({'side': 'left'})

        self.cancel = Button(self, text='Cancel', fg='black', padx=3, pady=3, width=6, command=self.quit)
        self.cancel.pack({'side': 'bottom'})

    def __init__(self, master=None):
        Frame.__init__(self, master,  padx=57, pady=20)
        self.pack()
        self.createWidgets()

# Classes for animated objects:
class Pointer(pygame.sprite.Sprite):


    def __init__(self):
        pygame.sprite.Sprite.__init__(self) #call Sprite initializer
        self.image = load_image('pointerPy.png', -1)
        self.rect = self.image.get_rect()
        #All these variables are just initializations
        self.poking = 0
        self.deflected = 0
        self.pos = np.zeros(2)
        self.vel = np.zeros(2)
        self.lastPos = np.zeros(2)
        self.time_since_pressed = 0
        self.pressed = False
        self.collidesTarget = False
        self.collidesTargetMotion = False
        self.clickStarted = False
        self.endImpulseSignal = False
        self.TemperatureWarning = False
        self.prematureStart = False

    #Method that updates the pointer every frame
    def update(self,buttons,target_button,actual_button,old_button_Motion,resolutionParameters):
        "move the pointer based on the arm position"
        srec = s.recv(512)
        if 'end' in srec:
            self.endImpulseSignal = True
            srec = srec.split(',')
            ind = srec.index('end')
            if ind == 0:
                pos0 = 1
                pos1 = 2
                vel0 = 3
                vel1 = 4
            else:
                pos0 = 0
                pos1 = 1
                vel0 = 2
                vel1 = 3

            try:
                self.pos[0],self.pos[1] = Robot2ScreenCoordinates(float(srec[pos0]),float(srec[pos1]),resolutionParameters)
                self.vel[0],self.vel[1] = [float(srec[vel0]),float(srec[vel1])]
            except: #ValueError
                print('Error when end is received!')
                pass

        elif 'temp' in srec:
            self.TemperatureWarning = True
        else:
            srec = srec.split(',')
            try:
                self.pos[0],self.pos[1] = Robot2ScreenCoordinates(float(srec[0]),float(srec[1]),resolutionParameters)
                self.vel[0],self.vel[1] = [float(srec[2]),float(srec[3])]
            except ValueError:
                pass


    		#ARMMOTION is called when the pointer leaves the old button to go to the new target
            if(self.collidesTargetMotion and not buttons[actual_button].rect.contains(self.rect)):
            	self.collidesTargetMotion = False
            	pygame.event.post(pygame.event.Event(ARMMOTION))



    		#ARMPRESSED and ARMRELEASED are called when you press or release with the robot
            isInTarget = buttons[target_button].rect.contains(self.rect)
            if isInTarget and self.clickStarted == False and self.prematureStart == False:
                self.tClick = pygame.time.get_ticks()
                self.clickStarted = True
            if isInTarget == False and self.clickStarted == True:
                self.clickStarted = False
            if isInTarget == True and self.clickStarted == True and pygame.time.get_ticks() >= self.tClick + TimeToClick:
                pygame.event.post(pygame.event.Event(ARMPRESSED))
                self.time_since_pressed = pygame.time.get_ticks()
                self.pressed = True
                self.clickStarted = False
            if self.pressed == True:
                pygame.event.post(pygame.event.Event(ARMRELEASED))
                self.pressed = False

            self.rect.topleft = self.pos
            self.lastPos = self.pos

    def poke(self,target,old_button_Motion):
        "returns true if the pointer collides with the target"
        if not self.poking:
            self.poking = 1
            hitbox = self.rect.inflate(-5, -5)
            self.collidesTarget = hitbox.colliderect(target.rect)
            self.collidesTargetMotion = hitbox.colliderect(old_button_Motion.rect)
            return self.collidesTarget

    def unpoke(self):
        "called to pull the pointer back"
        self.poking = 0

    def deflect(self,angle):
        if not self.deflected:
            self.deflected = 50
            self.rotation = array([[cos(deg2rad(angle)),-sin(deg2rad(angle))],[sin(deg2rad(angle)),cos(deg2rad(angle))]])

class TargetButton(pygame.sprite.Sprite):

    def __init__(self,color,position):
        pygame.sprite.Sprite.__init__(self)
        self.images = [load_image('button_'+str(color)+'_off.png', -1), load_image('button_'+str(color)+'_on.png', -1)]
        self.on = False
        self.image = self.images[0]
        self.rect = self.image.get_rect(center=position)
        self.click = load_sound('click.wav')
        self.ping = load_sound('ping.wav')

    def switch_on(self):
        if not self.on:
            self.ping.play()
            self.image = self.images[1]
            self.on = True

    def switch_off(self):
        if self.on:
            self.click.play()
            self.image = self.images[0]
            self.on = False


def getTriggerEvent(p):
    if p.endImpulseSignal:
        p.endImpulseSignal = False
        return 97 #End impulse trigger value
    else:
        return 0 #No trigger


# Main program function:
def main():
    trigger = Trigger('ARDUINO') # Arduino trigger
    if not trigger.init(400):#666
        print('LPT port cannot be opened. Closing program...')
        sys.exit()

    # Draw GUI for input of session name (used as filename for saving mouse/pointer positions):
    root = Tk()
    root.title('Input session data')
    root.geometry('%dx%d+%d+%d' % (250, 100, 1680/2, 1050/2))
    dlg = SessionInfoDlg(master=root)
    dlg.mainloop()
    root.destroy()

    
    #Initialize up variables used in storing mouse/pointer positions:
    mouse_positions = list()
    mouse_positions_file = file('C:\Users\Pablo\Documents\Universidad\MasterProject\Python\ArmData\\'+sessionInfo+'.txt','a')
    record_positions = False
    angles_file = open('C:\Users\Pablo\Documents\Universidad\MasterProject\Python\ArmData\\'+sessionInfo+'_angles.txt','a')
    meta_file = open('C:\Users\Pablo\Documents\Universidad\MasterProject\Python\ArmData\\'+sessionInfo+'_meta.txt','a')
    timing_file = open('C:\Users\Pablo\Documents\Universidad\MasterProject\Python\ArmData\\'+sessionInfo+'_timing.txt','a')

    # Initialize pygame:
    pygame.init()

    # Set up main clock:
    clock = pygame.time.Clock()

    # Set up main window:
    screen = pygame.display.set_mode((0,0),pygame.FULLSCREEN)
    W_res = pygame.display.Info().current_w
    H_res = pygame.display.Info().current_h
    resolutionParameters = buildResolutionParameters(W_res,H_res,distance)
    meta_file.write(str(W_res)+'\n'+str(H_res)+'\n'+str(distance)+'\n')
    screen_center = [screen.get_width()/2,screen.get_height()/2] # Center of the screen.
    frame_rate = 100


    # Prapare the backgound:
    background = pygame.Surface(screen.get_size())
    background = background.convert()
    background.fill((0,0,0))

    # Prepare sounds:
    miss = load_sound('miss.wav')

    # Prepare fonts:
    font = pygame.font.Font(None, 36)


    # Create the buttons:
    position = [[screen_center[0]-distance,screen_center[1]-distance],[screen_center[0]+distance,screen_center[1]-distance],[screen_center[0]+distance,screen_center[1]+distance],[screen_center[0]-distance,screen_center[1]+distance]]
    buttons = [TargetButton(i,position[i]) for i in range(4)]
    next_button = 0
    old_button = 0
    old_button_armMotion = 0

    # Create the mouse pointer:
    pointer = Pointer()
    old_pointer = []

    # Group all animated objects:
    active_sprites = pygame.sprite.OrderedUpdates(buttons,pointer)
    dirty_rects = [sprite.rect.copy() for sprite in active_sprites]

    #Define a set of possible deflection angles:
    deflection_angles = [-60,-40,-20,20,40,60]


    #Draw background and buttons, wait for 2 s:
    screen.blit(background,(0,0))
    [screen.blit(button.image,button.rect) for button in buttons]
    pygame.display.flip()
    pygame.time.wait(2000)

    # Make mouse invisible:
    pygame.mouse.set_visible(0)

    # Turn on the first button:
    buttons[next_button].switch_on()

    # Necessary variable initializations before first trial:
    rest_time = 301
    rest_rect = buttons[next_button].rect.copy()
    trial = 0

    sent98 = False
    resting = False
    trigger.signal(int(25))


    # Main loop, looping over video frames, runs for 500 trials:
    while trial < number_trials + 1:

        if resting:
            pointer.TemperatureWarning = False
            pygame.time.wait(1000)
            for event in pygame.event.get():
                if event.type == KEYDOWN and event.key == K_r:
                    s.send(b'S')
                    trigger.signal(int(25)) #Trigger for end rest
                    background.fill([0,0,0])
                    resting = False
        else:
            tickTime = clock.tick(frame_rate)

            # Count frames since pointer came to rest:
            if rest_rect.collidepoint(pointer.pos):#pygame.mouse.get_pos()):
                rest_time += tickTime#1

            
            # Handle input events:
            for event in pygame.event.get():

                if event.type == QUIT:
                    mouse_positions_file.close()
                    angles_file.close()
                    meta_file.close()
                    return

                #Escape event
                elif event.type == KEYDOWN and event.key == K_ESCAPE:
                    mouse_positions_file.close()
                    angles_file.close()
                    meta_file.close()
                    trigger.signal(int(28))
                    s.send(b'Z')
                    return

                #Pause event
                elif event.type == KEYDOWN and event.key == K_r:
                    if not resting:
                        s.send(b'R')
                        trigger.signal(int(26)) #Trigger for pause
                        resting = True
                        text = font.render('Resting',True,(255,255,255))
                        textpos = text.get_rect()
                        textpos.centerx = background.get_rect().centerx
                        textpos.centery = background.get_rect().centery - 200
                        background.blit(text,textpos)




                elif event.type == ARMPRESSED:
                    if pointer.poke(buttons[next_button],buttons[old_button_armMotion]) and buttons[next_button].on: # Execute if user hits a lit button.

                        # Save (append) all mouse positions from the finished trial, turn off recorder:
                        trigger.signal(int(next_button+1)) #Trigger for end trial
                        mouse_positions.append([0,0,0,0,int(next_button+1)])
                        timing_file.write('0\n')
                        #print(mouse_positions)
                        savetxt(mouse_positions_file, mouse_positions, fmt='%d', delimiter=',')
                        record_positions = False
                        mouse_positions = []

                        # Set next trial variables:
                        rest_rect = buttons[next_button].rect.copy()
                        buttons[next_button].switch_off()
                        old_button = next_button
                        next_button = (next_button+choice([-1,1]))%4
                        trialReady = False
                        trial += 1
                        print trial

                        # Refresh trial counter in the screen
                        background.fill([0,0,0])
                        text = font.render(str(trial-1),True,(255,255,255))
                        textpos = text.get_rect()
                        textpos.centerx = background.get_rect().centerx
                        textpos.centery = background.get_rect().centery
                        background.blit(text,textpos)

                        if pointer.TemperatureWarning:
                            s.send(b'R')
                            trigger.signal(int(27)) #Trigger for pause due to temperature warning
                            text = font.render('Temperature warning: automatic pause',True,(255,255,255))
                            textpos = text.get_rect()
                            textpos.centerx = background.get_rect().centerx
                            textpos.centery = background.get_rect().centery - 200
                            background.blit(text,textpos)
                            resting = True



                    else:
                        # Play whoop sound if used clicked outside the button:
                        miss.play()



                elif event.type is ARMRELEASED:
                    s.send(b'A,'+str(str(next_button)+','+str(old_button)))
                    rest_time = 0
                    pointer.unpoke()



                elif event.type is ARMMOTION: 
                    if rest_time < waitingTime or trialReady == False:
                        #sent98 = False
                        if sent98 == False:
                            trigger.signal(int(98)) #Trigger for premature start
                            sent98 = True
                        s.send(b'C')
                        rest_time = 0
                        pointer.collidesTargetMotion = True
                        pointer.prematureStart = True
                        buttons[next_button].switch_off()
                        

                    else:
                        [dirx,diry] = selectForceDir(old_button,next_button)
                        mag = selectForceMag(dirx,diry)
                        if np.random.choice([0,1],p=[probZero,1 - probZero]) == 1:
                            angle = float(mag)
                            hardTrigg = selectTriggerValue(mag,dirx,diry)
                            s.send(b'B,'+str(dirx)+','+str(diry)+','+str(mag))
                            trigger.signal(int(hardTrigg)) #Trigger for start trial and deflection value
                        else:
                            angle = 0
                            dirx = 0
                            diry = 0
                            s.send(b'B,'+str(dirx)+','+str(diry)+','+str(angle))
                            trigger.signal(int(99)) #Trigger for start trial and no deflection

                        old_button_armMotion = next_button
                        pointer.prematureStart = False
                        angles_file.write(str(trial) + ',' + str(angle)+','+str(dirx)+','+str(diry)+'\n')
                        record_positions = True

    				
            # Light up the next button if pointer came to rest for 1 second in home:
            if not buttons[next_button].on:
                if rest_time >= 1000:#1*frame_rate:
                    buttons[next_button].switch_on()
                    trigger.signal(int(next_button+11)) #Trigger for next button lightening up.
                    sent98 = False
                    trialReady = True

            # Update the pointer position:
            pointer.update(buttons,next_button,old_button,buttons[old_button_armMotion],resolutionParameters)#,mouse_positions)


            # Blit all:
            screen.blit(background,(0,0))
            active_sprites.draw(screen)

            # Refresh the display:
            refresh_regions = old_pointer + [sprite.rect for sprite in active_sprites]
            #pygame.display.update(refresh_regions)
            pygame.display.flip()
            old_pointer = [pointer.rect.copy()]

            #record_positions = True # I have put this here to record all the time because ARMMOTION event is not working
            #Record mouse and pointer positions:
            if record_positions:
                mouse_positions.append(pointer.rect.topleft+(pointer.vel[0],pointer.vel[1],getTriggerEvent(pointer)))
                timing_file.write(str(tickTime)+'\n')


    # Save/close all files, exit pygame:
    trigger.signal(int(26))
    pygame.time.wait(2000)
    mouse_positions_file.close()
    angles_file.close()
    meta_file.close()
    s.send(b'Z')
    pygame.quit()



#Call the main function when this script is executed:
if __name__ == '__main__': main()

