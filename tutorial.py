import sys
import pygame

#starting pygame
pygame.init()

#creating window
screen = pygame.display.set_mode((400, 500))
test_surface = pygame.Surface((100,100))
test_surface.fill((0,0,255))

#creating a rectange over the surface.
#can specify where the center goes ie center/top
test_rect = test_surface.get_rect(center = (300,250))

#creating a clock object for setting the FPS
clock = pygame.time.Clock() 

while True:
    for event in pygame.event.get(): #searching for a event
        if event.type == pygame.QUIT: #checking if user closes the window
            pygame.quit()
            sys.exit()
    
    screen.fill((175,215,70))

    #used to add surface or object on top of screen
    #can use rect to specify position
    screen.blit(test_surface, test_rect) 

    #displaying the screen
    pygame.display.update() 

    #this sets the while loop to run only 60 times per second
    clock.tick(60) 
