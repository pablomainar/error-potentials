#undef UNICODE

#define WIN32_LEAN_AND_MEAN

// Need to link with Ws2_32.lib
#pragma comment (lib, "Ws2_32.lib")
// #pragma comment (lib, "Mswsock.lib")

#define DEFAULT_BUFLEN 512
#define DEFAULT_PORT "27015"

#ifdef  _WIN64
#pragma warning (disable:4996)
#endif

#include <cstdio>
#include <cassert>

#if defined(WIN32)
# include <conio.h>
#else
# include "conio.h"
#endif

#include <HD/hd.h>
#include <HDU/hduVector.h>
#include <HDU/hduError.h>

#include <time.h>

#include <windows.h>
#include <winsock2.h>
#include <ws2tcpip.h>
#include <stdlib.h>
#include <stdio.h>
#include <iostream>
#include <string>

using namespace std;

/* ------- Variables declarations (you can change the values) ---------- */

// Force impulse:
int ImpulseType = 1; //1 for force impulse, 2 for wall impulse
int ImpulseDuration = 250;// in ms

// Gravity well:
bool activeWells = false; //use gravitational wells
const HDdouble kStiffness = 0.4; /* N/mm */
const HDdouble kGravityWellInfluence = 10; /* mm */

// Wall:
bool activeWall = true; //use virtual wall
const double delta = -50; //Position of the wall. Can range from -100 to 80. Must be the same in Python
const double planeStiffness = 1;//0.75; //Higher value means harder surface
const double popthroughForceThreshold = 1000.0; //Higher value means more force is needed to break the wall

// Temperature security:
const float temperatureSafeLimit = 0.92; // Must be below 1
/* ---------------------------------------------------------------------- */

// Code declarations (do not touch)
#define PI 3.14159265
time_t startTime = 0;
bool isOn = false;
hduVector3Dd force;
hduVector3Dd fImp;
hduVector3Dd fWall;
hduVector3Dd fWallbis;
hduVector3Dd fWallImp;
hduVector3Dd fWell;
SOCKET ClientSocket = INVALID_SOCKET;
char recvbuf[DEFAULT_BUFLEN];
int recvbuflen = DEFAULT_BUFLEN;
int frameCounter = 1;
hduVector3Dd wellPos;
fd_set readfds;
int selectResult = 0;
timeval t;
int iResult;
float previous_m;
float previous_b;
int oldbut;
int nextbut;
static int directionWall = 1;
float m;
char movementType;
bool stopImpulse = false;
float realMag;
bool TempWarningSent = false;

struct ImpulseCommands {
	int dirx = 0;
	int diry = 0;
	float mag = -1;
	int oldbut = -1;
	int nextbut = -1;
	bool finish = false;
};

// This method converts the position into a string and sends it to python
void sendPosition(hduVector3Dd pos, hduVector3Dd vel) {

	int temp = abs(pos[0]);
	char xpos[4];
	if (pos[0] < 0) {
		xpos[0] = '-' ;
	}
	else {
		xpos[0] = '+';
	}
	xpos[1] = temp / 100 + '0';
	temp = temp - (temp / 100) * 100;
	xpos[2] = temp / 10 + '0';
	temp = temp - (temp / 10) * 10;
	xpos[3] = temp + '0';
	/*
	temp = abs(pos[1]);
	char ypos[4];
	if (pos[1] < 0) {
		ypos[0] = '-';
	}
	else {
		ypos[0] = '+';
	}
	ypos[1] = temp / 100 + '0';
	temp = temp - (temp / 100) * 100;
	ypos[2] = temp / 10 + '0';
	temp = temp - (temp / 10) * 10;
	ypos[3] = temp + '0';
	*/
	temp = abs(pos[2]);
	char zpos[4];
	if (pos[2] < 0) {
		zpos[0] = '-';
	}
	else {
		zpos[0] = '+';
	}
	zpos[1] = temp / 100 + '0';
	temp = temp - (temp / 100) * 100;
	zpos[2] = temp / 10 + '0';
	temp = temp - (temp / 10) * 10;
	zpos[3] = temp + '0';



	
	temp = abs(vel[0]);
	char xvel[4];
	if (vel[0] < 0) {
		xvel[0] = '-';
	}
	else {
		xvel[0] = '+';
	}
	xvel[1] = temp / 100 + '0';
	temp = temp - (temp / 100) * 100;
	xvel[2] = temp / 10 + '0';
	temp = temp - (temp / 10) * 10;
	xvel[3] = temp + '0';
	/*
	temp = abs(vel[1]);
	char yvel[4];
	if (vel[1] < 0) {
		yvel[0] = '-';
	}
	else {
		yvel[0] = '+';
	}
	yvel[1] = temp / 100 + '0';
	temp = temp - (temp / 100) * 100;
	yvel[2] = temp / 10 + '0';
	temp = temp - (temp / 10) * 10;
	yvel[3] = temp + '0';
	*/
	temp = abs(vel[2]);
	char zvel[4];
	if (vel[2] < 0) {
		zvel[0] = '-';
	}
	else {
		zvel[0] = '+';
	}
	zvel[1] = temp / 100 + '0';
	temp = temp - (temp / 100) * 100;
	zvel[2] = temp / 10 + '0';
	temp = temp - (temp / 10) * 10;
	zvel[3] = temp + '0';
	
	// Mind this!! the ypos and zpos (and yvel and zvel) have been swapped in order to change the plane of action from a wall to the floor
	char csend[20] = { xpos[0],xpos[1], xpos[2], xpos[3], ',',
					zpos[0], zpos[1], zpos[2], zpos[3], ',',
					//ypos[0], ypos[1], ypos[2], ypos[3], ',' 
					xvel[0], xvel[1], xvel[2], xvel[3], ',',
					zvel[0], zvel[1], zvel[2], zvel[3], ',' };
					//yvel[0], yvel[1], yvel[2], yvel[3], ','};

int iSendResult = send(ClientSocket, csend, 20, 0);
}

void sendEndImpulseSignal() {
	char cSendEnd[4] = { 'e','n','d',',' };
	int iSendImpulseEndResult = send(ClientSocket, cSendEnd, 4, 0);
}

void sendTemperatureWarning() {
	char cSendTemp[4] = { 't','e','m','p' };
	int iSendTemp = send(ClientSocket, cSendTemp, 4, 0);
}

// Function to receive the commands sent from python
ImpulseCommands getCommands() {
	ImpulseCommands com;
	FD_ZERO(&readfds);
	FD_SET(ClientSocket, &readfds);
	t.tv_sec = 0;
	t.tv_usec = 5;
	selectResult = select(0, &readfds, NULL, NULL, &t);
	if (selectResult > 0) {
		iResult = recv(ClientSocket, recvbuf, recvbuflen, 0);
		if (iResult > 0) {
			std::string message = recvbuf;
			std::string type = message.substr(0, 1);
			if (type == "A") {
				std::string snextbut = message.substr(2, 1);
				std::string soldbut = message.substr(4, 1);
				int nextbut = atoi(snextbut.c_str());
				int oldbut = atoi(soldbut.c_str());
				com.nextbut = nextbut;
				com.oldbut = oldbut;
			}
			else if (type == "B") {
				stopImpulse = false;
				std::string sdirx = message.substr(2, 1);
				std::string sdiry = message.substr(4, 1);
				std::string smag = message.substr(6, 3);
				int dirx = atoi(sdirx.c_str());
				int diry = atoi(sdiry.c_str());
				float mag = atof(smag.c_str());

				if (dirx == 2) { //A 2 is sent to indicate the negative direction
					com.dirx = -1;
				}
				else {
					com.dirx = dirx;
				}
				if (diry == 2) {
					com.diry = -1;
				}
				else {
					com.diry = diry;
				}
				com.mag = mag;
			}
			else if (type == "Z") {
				com.finish = true;
			}
			else if (type == "C") {
				stopImpulse = true;
			}
			else if (type == "R") {
				activeWall = false;
			}
			else if (type == "S") {
				activeWall = true;
				TempWarningSent = false;
			}

			return com;
		}
		else return com;
	}
	else return com;

}

char getMovementType(int oldb, int newb) {
	if ((oldb == 0 && newb == 3) ||
		(oldb == 1 && newb == 2) ||
		(oldb == 2 && newb == 1) ||
		(oldb == 3 && newb == 0)) {
		return 'V'; //Vertical movement
	}
	else {
		return 'H'; //Horizontal movement
	}
}

char findPerturbationDirection(int dx, int dy) {
	char pertDir;
	if (dx == 1) pertDir = 'R';
	else if (dx == -1) pertDir = 'L';
	else if (dy == 1) pertDir = 'U';
	else if (dy == -1) pertDir = 'D';
	return pertDir;
}

// Function to turn the force magnitude orders into real force values depending on the direction of the movement
float findRealMag(float abstractMag, int dx, int dy) {
	float rMag;
	if (abstractMag == 0) {
		rMag = 0;
	}
	else {
		switch (findPerturbationDirection(dx, dy)) {
		case 'R':
			if (abstractMag == 1) rMag = 1;
			else if (abstractMag == 2) rMag = 1.5;
			else if (abstractMag == 3) rMag = 2.7;
			break;
		case 'L':
			if (abstractMag == 1) rMag = 1;
			else if (abstractMag == 2) rMag = 1.5;
			else if (abstractMag == 3) rMag = 2.7;
			break;
		case 'U':
			if (abstractMag == 1) rMag = 1.8;
			else if (abstractMag == 2) rMag = 2.6;
			else if (abstractMag == 3) rMag = 4.7;
			break;
		case 'D':
			if (abstractMag == 1) rMag = 2;
			else if (abstractMag == 2) rMag = 3.6;
			else if (abstractMag == 3) rMag = 5.6;
			break;
		}
	}
	return rMag;
}




/*******************************************************************************
 Haptic code callback.
*******************************************************************************/
HDCallbackCode HDCALLBACK FrictionlessPlaneCallback(void *data)
{
	hdBeginFrame(hdGetCurrentDevice());

	// Get the position of the device.
	hduVector3Dd position;
	hdGetDoublev(HD_CURRENT_POSITION, position);
	// Get the velocity of the device.
	hduVector3Dd velocity;
	hdGetDoublev(HD_CURRENT_VELOCITY, velocity);
	// Get the temperature of the device.
	hduVector3Dd temp;
	hdGetDoublev(HD_MOTOR_TEMPERATURE, temp);

	if ((temp[0] > temperatureSafeLimit || temp[1] > temperatureSafeLimit || temp[2] > temperatureSafeLimit) && TempWarningSent == false) {
		TempWarningSent = true;
		sendTemperatureWarning();
	}

	// Send position to python every 10 frames
	if (frameCounter % 10 == 0) {
		sendPosition(position,velocity);
		frameCounter = 1;
	}
	else {
		frameCounter = frameCounter + 1;
	}


	// --------------------- WALL STUFF -------------------------------
	if (activeWall == true) {
		// Plane direction changes whenever the user applies sufficient
		// force to popthrough it.
		// 1 means the plane is facing +Z.
		// -1 means the plane is facing -Z.
		static int directionFlag = 1;

		// If the user has penetrated the plane, set the device force to 
		// repel the user in the direction of the surface normal of the plane.
		// Penetration occurs if the plane is facing in +Z and the user's Z position
		// is negative, or vice versa.

		if ((position[1] <= delta && directionFlag > 0) ||
			(position[1] > delta && directionFlag < 0))
		{
			// Create a force vector repelling the user from the plane proportional
			// to the penetration distance, using F=kx where k is the plane 
			// stiffness and x is the penetration vector.  Since the plane is 
			// oriented at the Y=0, the force direction is always either directly 
			// upward or downward, i.e. either (0,1,0) or (0,-1,0).
			double penetrationDistance;
			if (directionFlag > 0) penetrationDistance = -position[1] + delta;
			else penetrationDistance = position[1] - delta;

			//double penetrationDistance = fabs(position[2]);
			hduVector3Dd forceDirection(0, directionFlag, 0);

			// Hooke's law explicitly:
			double k = planeStiffness;
			hduVector3Dd x = penetrationDistance*forceDirection;
			fWall = k*x;

			// If the user applies sufficient force, pop through the plane
			// by reversing its direction.  Otherwise, apply the repel
			// force.
			if (fWall.magnitude() > popthroughForceThreshold)
			{
				fWall.set(0.0, 0.0, 0.0);
				directionFlag = -directionFlag;
			}

		}
	}
	else {
		fWall.set(0, 0, 0);
	}



	/* VERTICAL WALL (not used)
	if (activeWall == true) {
		// Plane direction changes whenever the user applies sufficient
		// force to popthrough it.
		// 1 means the plane is facing +Z.
		// -1 means the plane is facing -Z.
		static int directionFlag = 1;

		// If the user has penetrated the plane, set the device force to 
		// repel the user in the direction of the surface normal of the plane.
		// Penetration occurs if the plane is facing in +Z and the user's Z position
		// is negative, or vice versa.

		if ((position[2] <= delta && directionFlag > 0) ||
			(position[2] > delta && directionFlag < 0))
		{
			// Create a force vector repelling the user from the plane proportional
			// to the penetration distance, using F=kx where k is the plane 
			// stiffness and x is the penetration vector.  Since the plane is 
			// oriented at the Y=0, the force direction is always either directly 
			// upward or downward, i.e. either (0,1,0) or (0,-1,0).
			double penetrationDistance;
			if (directionFlag > 0) penetrationDistance = -position[2] + delta;
			else penetrationDistance = position[2] - delta;

			//double penetrationDistance = fabs(position[2]);
			hduVector3Dd forceDirection(0, 0, directionFlag);

			// Hooke's law explicitly:
			double k = planeStiffness;
			hduVector3Dd x = penetrationDistance*forceDirection;
			fWall = k*x;

			// If the user applies sufficient force, pop through the plane
			// by reversing its direction.  Otherwise, apply the repel
			// force.
			if (fWall.magnitude() > popthroughForceThreshold)
			{
				fWall.set(0.0, 0.0, 0.0);
				directionFlag = -directionFlag;
			}

		}
	}*/
	

	// -------------------------------------------------------------------------------

	ImpulseCommands com = getCommands();
	switch (ImpulseType) {
	case 1: // Force impulse
		if (com.finish == true) {
			return HD_CALLBACK_DONE;
		}
		if (stopImpulse == true) {
			fImp.set(0, 0, 0);
			isOn = false;
		}

		//if (com.dirx != 0 || com.diry != 0 || com.mag != 0) {
		if (com.mag != -1) {
			realMag = findRealMag(com.mag,com.dirx,com.diry);
			fImp.set(realMag * com.dirx, 0, realMag * com.diry); //Mind this!! y and z are swapped for the new plane
			startTime = clock() * 1000.0 / CLOCKS_PER_SEC;
			isOn = true;
		}
		else if (isOn == true) {
			if (clock() * 1000 / CLOCKS_PER_SEC > startTime + ImpulseDuration) {
				isOn = false;
				sendEndImpulseSignal();
				fImp.set(0, 0, 0);
				
			}
		}
		break;


	case 2: // Wall impulse
		if (com.nextbut != -1) {
			oldbut = com.oldbut;
			nextbut = com.nextbut;
		}
		
		if (com.finish == true) {
			return HD_CALLBACK_DONE;
		}
		if (stopImpulse == true) {
			fImp.set(0, 0, 0);
			isOn = false;
		}

		if (com.dirx != 0 || com.diry != 0 || com.mag != 0) {
			movementType = getMovementType(oldbut, nextbut);
			startTime = clock() * 1000.0 / CLOCKS_PER_SEC;
			isOn = true;
			switch (movementType) {
			case 'V':
				m = tan(PI/2 - com.mag * PI/180);
				break;
			case 'H':
				m = tan(com.mag * PI/180);
				break;
			}
			previous_m = m;
			previous_b = m * position[0] - position[1];
			switch (oldbut) {
			case 0:
				if (m > 0) directionWall = 1;				
				else {
					if (nextbut == 1) directionWall = -1;
					else directionWall = 1;
				}
				break;
			case 1:
				if (m > 0) {
					if (nextbut == 0) directionWall = -1;
					else directionWall = 1;
				}
				else directionWall = 1;
				break;
			case 2:
				if (m > 0)	directionWall = -1;
				else {
					if (nextbut == 1) directionWall = -1;
					else directionWall = 1;
				}
				break;
			case 3:
				if (m > 0) {
					if (nextbut == 0) directionWall = -1;
					else directionWall = 1;
				}
				else directionWall = -1;
				break;
			}
		}
		else if (isOn == true) {
			double penetrationDistancebis = position[1] - previous_m*position[0] + previous_b;
			if ((penetrationDistancebis <= 0 && directionWall == 1) ||
				(penetrationDistancebis >= 0 && directionWall == -1)) {
				hduVector3Dd forceDirection;
				forceDirection.set(-previous_m, 1, 0);
				forceDirection = directionWall * forceDirection;
				hduVector3Dd x = fabs(penetrationDistancebis)*forceDirection;
				double k = planeStiffness;
				fImp = k*x;
			}
			if (clock() * 1000 / CLOCKS_PER_SEC > startTime + ImpulseDuration) {
				isOn = false;
				fImp.set(0, 0, 0);
				//printf("\n\n\n\n");
			}
		}
		break;
	default:
		printf("Wrong type of impulse!");
	}


	// --------------------- GRAVITY WELL STUFF ------------------------------------

	switch (com.nextbut) {
	case 0:
		wellPos = { -45,40,delta+1 }; //The wells Y position depends on the Y positions on buildResolutionParameters on python
		break;
	case 1:
		wellPos = { 47,40,delta+1 };
		break;
	case 2:
		wellPos = { 47,-45,delta+1 };
		break;
	case 3:
		wellPos = { -45,-45,delta+1 };
		break;
	}
	
	if (activeWells){
		if (stopImpulse == true) {
			fWell.set(0, 0, 0);
		}
		else {
			hduVector3Dd positionTwell;

			hduVecSubtract(positionTwell, wellPos, position);
			if (hduVecMagnitude(positionTwell) < kGravityWellInfluence)
			{
				// >  F = k * x  <
				//F: Force in Newtons (N)
				//k: Stiffness of the well (N/mm)
				//x: Vector from the device endpoint position to the center
				//of the well.
				hduVecScale(fWell, positionTwell, kStiffness);
			}
			else {
				fWell.set(0, 0, 0);
			}

		}
	}
	
	// ----------------------------------------------------------------------------
	
	// Add the wall force with the impulse force
	force = fWall + fImp + fWell;
	hdSetDoublev(HD_CURRENT_FORCE, force);

	
    hdEndFrame(hdGetCurrentDevice());

    // In case of error, terminate the callback.
    HDErrorInfo error;
    if (HD_DEVICE_ERROR(error = hdGetError()))
    {
        hduPrintError(stderr, &error, "Error detected during main scheduler callback\n");

        if (hduIsSchedulerError(&error))
        {
            return HD_CALLBACK_DONE;  
        }
    }

	return HD_CALLBACK_CONTINUE;
}


SOCKET initializeSockets() {
	WSADATA wsaData;
	int iResult;

	SOCKET ListenSocket = INVALID_SOCKET;
	SOCKET ClientSocket = INVALID_SOCKET;

	struct addrinfo *result = NULL;
	struct addrinfo hints;

	int iSendResult;
	char recvbuf[DEFAULT_BUFLEN];
	int recvbuflen = DEFAULT_BUFLEN;

	// Initialize Winsock
	iResult = WSAStartup(MAKEWORD(2, 2), &wsaData);
	if (iResult != 0) {
		printf("WSAStartup failed with error: %d\n", iResult);
		return 1;
	}

	ZeroMemory(&hints, sizeof(hints));
	hints.ai_family = AF_INET;
	hints.ai_socktype = SOCK_STREAM;
	hints.ai_protocol = IPPROTO_TCP;
	hints.ai_flags = AI_PASSIVE;

	// Resolve the server address and port
	iResult = getaddrinfo(NULL, DEFAULT_PORT, &hints, &result);
	if (iResult != 0) {
		printf("getaddrinfo failed with error: %d\n", iResult);
		WSACleanup();
		return 1;
	}

	// Create a SOCKET for connecting to server
	ListenSocket = socket(result->ai_family, result->ai_socktype, result->ai_protocol);
	if (ListenSocket == INVALID_SOCKET) {
		printf("socket failed with error: %ld\n", WSAGetLastError());
		freeaddrinfo(result);
		WSACleanup();
		return 1;
	}

	// Setup the TCP listening socket
	iResult = bind(ListenSocket, result->ai_addr, (int)result->ai_addrlen);
	if (iResult == SOCKET_ERROR) {
		printf("bind failed with error: %d\n", WSAGetLastError());
		freeaddrinfo(result);
		closesocket(ListenSocket);
		WSACleanup();
		return 1;
	}

	freeaddrinfo(result);

	iResult = listen(ListenSocket, SOMAXCONN);
	if (iResult == SOCKET_ERROR) {
		printf("listen failed with error: %d\n", WSAGetLastError());
		closesocket(ListenSocket);
		WSACleanup();
		return 1;
	}

	printf("Waiting for client to connect...\n");
	// Accept a client socket
	ClientSocket = accept(ListenSocket, NULL, NULL);
	if (ClientSocket == INVALID_SOCKET) {
		printf("accept failed with error: %d\n", WSAGetLastError());
		closesocket(ListenSocket);
		WSACleanup();
		return 1;
	}

	// No longer need server socket
	closesocket(ListenSocket);

	printf("Socket connection created\n");
	return ClientSocket;
}


/*******************************************************************************
 * main function
   Initializes the device, creates a callback to handles plane forces, 
   terminates upon key press.
 ******************************************************************************/
int main(int argc, char* argv[])
{
    HDErrorInfo error;

	// Initialize socket connection 
	ClientSocket = initializeSockets();

    // Initialize the default haptic device.
    HHD hHD = hdInitDevice(HD_DEFAULT_DEVICE);
    if (HD_DEVICE_ERROR(error = hdGetError()))
    {
        hduPrintError(stderr, &error, "Failed to initialize haptic device");
        fprintf(stderr, "\nPress any key to quit.\n");
        getch();
        return -1;
    }

    // Start the servo scheduler and enable forces.
    hdEnable(HD_FORCE_OUTPUT);
    hdStartScheduler();
    if (HD_DEVICE_ERROR(error = hdGetError()))
    {
        hduPrintError(stderr, &error, "Failed to start the scheduler");
        fprintf(stderr, "\nPress any key to quit.\n");
        getch();
        return -1;
    }

	 
    // Schedule the frictionless plane callback, which will then run at 
    // servoloop rates and command forces if the user penetrates the plane.
    HDCallbackCode hPlaneCallback = hdScheduleAsynchronous(
        FrictionlessPlaneCallback, 0, HD_DEFAULT_SCHEDULER_PRIORITY);

    printf("Master Project experiment.\n");
    printf("Press any key to quit.\n\n");

    while (!_kbhit())
    {       
        if (!hdWaitForCompletion(hPlaneCallback, HD_WAIT_CHECK_STATUS))
        {
            fprintf(stderr, "\nThe main scheduler callback has exited\n");
            fprintf(stderr, "\nClosing program\n");
            break;
        }
    }

	// shutdown the connection since we're done
	iResult = shutdown(ClientSocket, SD_SEND);
	if (iResult == SOCKET_ERROR) {
		printf("shutdown failed with error: %d\n", WSAGetLastError());
		closesocket(ClientSocket);
		WSACleanup();
		return 1;
	}

	// cleanup
	closesocket(ClientSocket);
	WSACleanup();
    // Cleanup and shutdown the haptic device, cleanup all callbacks.
    hdStopScheduler();
    hdUnschedule(hPlaneCallback);
    hdDisableDevice(hHD);

    return 0;
}

/*****************************************************************************/


