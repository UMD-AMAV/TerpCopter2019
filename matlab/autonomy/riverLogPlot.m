clear all;
close all;

clc;

[file,path] = uigetfile('../*.log');

file
filepath = [path file ];
data = csvread(filepath);

% parse out
t = data(:,1);
t = t - t(1);
% TODO : fix time

% pFile = fopen( riverLog  ,'a');
% fprintf(pFile,'%6.6f,',bhvTime);
% fprintf(pFile,'%6.6f,',rDetected);
% fprintf(pFile,'%6.6f,',yLeft);
% fprintf(pFile,'%6.6f,',yRight);
% fprintf(pFile,'%6.6f,',yMid);
% fprintf(pFile,'%6.6f,',yError);
% fprintf(pFile,'%6.6f,',filtPixelY);
% fprintf(pFile,'%6.6f,',delY);
% fprintf(pFile,'%6.6f,',rAngle);
% fprintf(pFile,'%6.6f,',desiredYaw);


% fprintf(pFile,'%6.6f,',errorSumY);
% fprintf(pFile,'%6.6f,',diffY);
% fprintf(pFile,'%6.6f,',pitchCmd);
% fprintf(pFile,'%6.6f,',ayprCmd.PitchDesiredDegrees);
% fprintf(pFile,'%6.6f,',ayprCmd.YawDesiredDegrees);
% fprintf(pFile,'%6.6f,',theta);
% fprintf(pFile,'%6.6f,\n',yaw);
% fclose(pFile);

rDetected = data(:,2);
yLeft = data(:,3);
yRight = data(:,4);
yMid = data(:,5);
yError = data(:,6);

filtPixelY = data(:,7);
delY = data(:,8);
rAngle = data(:,9);
desiredYaw = data(:,10);

errorSumY = data(:,11);
diffY = data(:,12);
pitchCmdUnsat = data(:,13);
pitchCmd = data(:,14);
yawCmd = data(:,15);
pitch = data(:,16);
yaw = data(:,17);


% 
figure;
subplot(2,1,1);
plot(t,yError);
hold on;
plot(t,filtPixelY);
legend('yError','filtPixelY');

subplot(2,1,2);
plot(t,pitchCmd*100);
hold on;
plot(t,pitch);
legend('pitchCmd*100','pitch');

% 
figure;
subplot(3,1,1);
plot(t,delY);
hold on;
legend('delY');

subplot(3,1,2);
plot(t,desiredYaw);
hold on;
plot(t,yaw);
legend('desiredYaw','yaw');

subplot(3,1,2);
plot(t,rAngle);
hold on;
legend('rAngle');
