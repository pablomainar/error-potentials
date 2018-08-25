
#/usr/bin/env python

# Import modules:
import os, pygame
from random import randint, sample, choice
from pygame.locals import *
import numpy as np
from numpy import loadtxt, savetxt, deg2rad, array, eye, cos, sin, dot, add, subtract
from Tkinter import *
import socket
from utilitiesHapticPassive import *

# Variables: Normally only need to change the IP adress
number_trials = 250 #Number of trials
HOST, PORT = "128.179.182.226",27015 #IP adress of this computer (to communicate with the robot ccontroler process)
delta = -50 #Position of the wall. Must be the same as in C++
zeroProb = 0.65 #Probablity of not having any distorsion
distance = 125 #This sets distances between buttons.
TimeToClick = 1000 #Time that the user has to be inside the target to make a click, in ms
restingTime = 2000 #Time between trials

# Variables initialization (do not touch)
W_res = 0
H_res = 0


# Connect with the other process, that should be listening for connections
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect((HOST, PORT))

# Define pyame events
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
        self.pos = np.zeros(2)
        self.vel = np.zeros(2)
        self.time_since_pressed = 0
        self.pressed = False
        self.collidesTarget = False
        self.collidesTargetMotion = False
        self.clickStarted = False
        self.timerFlag = False
        self.timer = 0
        self.TemperatureWarning = False
        self.questionAnswered = False

    #Method that updates the pointer every frame
    def update(self,buttons,target_button,actual_button,old_button_Motion,resolutionParameters):
        "move the pointer based on the arm position"
        srec = s.recv(512)
        if 'temp' in srec:
            self.TemperatureWarning = True
        else:
            srec = srec.split(',')
            zpos = 0
            try:
                self.pos[0],self.pos[1] = Robot2ScreenCoordinates(float(srec[0]),float(srec[1]),resolutionParameters)
                #zpos = int(srec[2])
                self.vel[0],self.vel[1] = [float(srec[2]),float(srec[3])]
            except ValueError:
                pass


            #ARMPRESSED is called when the pointer stays for a certain time in the target
            #ARMRELEASED is called a certain time after ARMPRESSED has been called
            isInTarget = buttons[target_button].rect.contains(self.rect)
            if isInTarget == True and self.clickStarted == False:
                self.tClick = pygame.time.get_ticks()
                self.clickStarted = True
            if isInTarget == False and self.clickStarted == True:
                self.clickStarted = False
            if isInTarget == True and self.clickStarted == True and pygame.time.get_ticks() >= self.tClick + TimeToClick:
                pygame.event.post(pygame.event.Event(ARMPRESSED))
                #self.time_since_pressed = pygame.time.get_ticks()
                self.pressed = True
                self.clickStarted = False


            if buttons[actual_button].rect.contains(self.rect) and self.pressed and self.questionAnswered == True:
                self.timer = pygame.time.get_ticks()
                self.timerFlag = True
                self.pressed = False
                self.questionAnswered = False
            if self.timerFlag == True and pygame.time.get_ticks() >= self.timer + restingTime:
                pygame.event.post(pygame.event.Event(ARMRELEASED))
                self.timerFlag = False



            self.rect.topleft = self.pos

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

# Main program function:
def main():
    trigger = Trigger('ARDUINO') # Arduino trigger
    if not trigger.init(300):#666
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
    timing_positions = list()
    mouse_positions_file = file('C:\Users\Pablo\Documents\Universidad\MasterProject\Python\ArmData\\'+sessionInfo+'.txt','a')
    record_positions = False
    angles_file = open('C:\Users\Pablo\Documents\Universidad\MasterProject\Python\ArmData\\'+sessionInfo+'_angles.txt','a')
    meta_file = open('C:\Users\Pablo\Documents\Universidad\MasterProject\Python\ArmData\\'+sessionInfo+'_meta.txt','a')
    timing_file = open('C:\Users\Pablo\Documents\Universidad\MasterProject\Python\ArmData\\'+sessionInfo+'_timing.txt','a')
    questions_file = open('C:\Users\Pablo\Documents\Universidad\MasterProject\Python\ArmData\\'+sessionInfo+'_questions.txt','a')

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
    #font = pygame.font.SysFont('dejavusans', 14)
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


    #Draw background and buttons, wait for 2 s:
    screen.blit(background,(0,0))
    [screen.blit(button.image,button.rect) for button in buttons]
    pygame.display.flip()
    pygame.time.wait(2000)

    # Make mouse invisible:
    pygame.mouse.set_visible(0)

    # Turn on the first button:
    buttons[next_button].switch_on()
    questionAnswered = False

    # Necessary variable initializations before first trail:
    rest_time = 301
    rest_rect = buttons[next_button].rect.copy()
    trial = 0

    resting = 0
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


                elif event.type == KEYDOWN and (event.key == K_y or event.key == K_n):
                    if trial != 1:
                        if pointer.pressed == True:
                            pointer.questionAnswered = True
                            background.fill([0,0,0])
                            text = font.render(str(trial-1),True,(255,255,255))
                            textpos = text.get_rect()
                            textpos.centerx = background.get_rect().centerx
                            textpos.centery = background.get_rect().centery
                            background.blit(text,textpos)
                            if event.key == K_y:
                                questions_file.write(str(trial-1)+',1\n')
                            elif event.key == K_n:
                                questions_file.write(str(trial-1)+',0\n')
                            questionAnswered = True




                elif event.type == ARMPRESSED:
                    if pointer.poke(buttons[next_button],buttons[old_button_armMotion]) and buttons[next_button].on: # Execute if user hits a lit button.

                        # Save (append) all mouse positions from the finished trial, turn off recorder:
                        trigger.signal(int(next_button+1)) #Trigger for end trial
                        mouse_positions.append([0,0,0,0,int(next_button+1)])
                        timing_file.write('0\n')
                        savetxt(mouse_positions_file, mouse_positions, fmt='%d', delimiter=',')
                        record_positions = False
                        mouse_positions = []

                        # Set next trial variables:
                        rest_rect = buttons[next_button].rect.copy()
                        buttons[next_button].switch_off()
                        old_button = next_button
                        next_button = (next_button+choice([-1,1]))%4
                        rest_time = 0
                        trial += 1
                        print trial


                        # Refresh trial counter in the screen
                        background.fill([0,0,0])
                        text = font.render(str(trial-1),True,(255,255,255))
                        textpos = text.get_rect()
                        textpos.centerx = background.get_rect().centerx
                        textpos.centery = background.get_rect().centery
                        background.blit(text,textpos)
                        if trial != 1:
                            textQuestion = font.render('Did you perceive any deviation? (y/n)',True,(255,255,255))
                            textposQuestion = textQuestion.get_rect()
                            textposQuestion.centerx = background.get_rect().centerx
                            textposQuestion.centery = background.get_rect().centery - 200
                            background.blit(textQuestion,textposQuestion)
                        else:
                            pointer.questionAnswered = True
                            questionAnswered = True

                        if pointer.TemperatureWarning:
                            s.send(b'R')
                            trigger.signal(int(27)) #Trigger for paause due to temperature warning
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
                    mag,magTrig,const = selectDeviation(zeroProb)
                    record_positions = True
                    s.send(b'D,'+str(mag)+','+str(const))#Has de mandar magnitud del desvio y el sentido (positivo o negativo)
                    trigger.signal(int(magTrig)) #Trigger for trial start and magnitude
                    #mouse_positions.append([1,1])
                    angles_file.write(str(trial)+','+str(mag)+','+str(const)+'\n')
                    pointer.unpoke()



                    
            # Light up the next button if pointer came to rest for 1 second in home:
            if not buttons[next_button].on:
                if questionAnswered == True and rest_time >= 1000:#1*frame_rate:
                    buttons[next_button].switch_on()
                    trigger.signal(int(next_button+11)) #Trigger for next button lightening up.
                    s.send(b'A,'+str(str(next_button)+','+str(old_button)))
                    questionAnswered = False

            # Update the pointer position:
            pointer.update(buttons,next_button,old_button,buttons[old_button_armMotion],resolutionParameters)

            # Blit all:
            screen.blit(background,(0,0))
            active_sprites.draw(screen)

            # Refresh the display:
            refresh_regions = old_pointer + [sprite.rect for sprite in active_sprites]
            #pygame.display.update(refresh_regions)
            pygame.display.flip()
            old_pointer = [pointer.rect.copy()]

            #Record mouse and pointer positions:
            if record_positions:
                mouse_positions.append(pointer.rect.topleft+(pointer.vel[0],pointer.vel[1],0))
                timing_file.write(str(tickTime)+'\n')

    # Save/close all files, exit pygame:
    trigger.signal(int(26))
    pygame.time.wait(2000)
    mouse_positions_file.close()
    angles_file.close()
    meta_file.close()
    pygame.quit()



#Call the main function when this script is executed:
if __name__ == '__main__': main()

