function altControlDebugCallback( subscriber, altControlDebugMsg )


curTime = altControlDebugMsg.T;
zd = altControlDebugMsg.Zd;
zcur = altControlDebugMsg.Zcur;
altRateDes = altControlDebugMsg.AltRateDes;
altRateActual = altControlDebugMsg.AltRateActual;
altRateError = altControlDebugMsg.AltRateError;
altRateErrorRate = altControlDebugMsg.AltRateErrorRate;
altRateErrorIntegral = altControlDebugMsg.AltRateErrorIntegral;


pterm = altControlDebugMsg.Proportional;
iterm = altControlDebugMsg.Integral;
dterm = altControlDebugMsg.Derivative;
thrustCmdUnsat = altControlDebugMsg.ThrustCmdUnsat;
thrustCmd = altControlDebugMsg.ThrustCmd;


figure(100);
scrollTime = 30; %s
tmin = curTime - scrollTime;

subplot(1,2,1)
ms = 4;
lw = 2;
plot(curTime,zd,'r+','Linewidth',lw,'MarkerSize',ms);
hold on;
plot(curTime,zcur,'bo','Linewidth',lw,'MarkerSize',ms);
xlim([tmin,curTime]);
xlabel('Time (sec)');
ylabel('Altitude (m)');
set(gca,'FontSize',16)
ylim([0 2]);
grid on;

subplot(1,2,2)
plot(curTime,altRateDes,'r+','Linewidth',lw,'MarkerSize',ms);
hold on;
plot(curTime,altRateActual,'bo','Linewidth',lw,'MarkerSize',ms);
xlim([tmin,curTime]);
xlabel('Time (sec)');
ylabel('Altitude-Rate (m/s)');
set(gca,'FontSize',16)
grid on;
ylim([-0.5 0.5])



%%
figure(101);

subplot(2,3,1)
plot(curTime,altRateError,'bo','Linewidth',lw,'MarkerSize',ms);
hold on;
xlim([tmin,curTime]);
xlabel('Time (sec)');
ylabel('Error (m/s)');
set(gca,'FontSize',16)
grid on;

subplot(2,3,2)
hold on;
plot(curTime,altRateErrorRate,'bo','Linewidth',lw,'MarkerSize',ms);
hold on;
xlim([tmin,curTime]);
xlabel('Time (sec)');
ylabel('Error Rate (m/s^2)');
set(gca,'FontSize',16)
grid on;

subplot(2,3,3)
plot(curTime,altRateErrorIntegral,'bo','Linewidth',lw,'MarkerSize',ms);
hold on;
xlim([tmin,curTime]);
xlabel('Time (sec)');
ylabel('Error Integral (m/s)');
set(gca,'FontSize',16)
grid on;

subplot(2,3,4)
plot(curTime, pterm ,'bo','Linewidth',lw,'MarkerSize',ms);
hold on;
plot(curTime, thrustCmd ,'k*','Linewidth',lw,'MarkerSize',ms);
plot(curTime, thrustCmdUnsat ,'mo','Linewidth',lw,'MarkerSize',ms);
hold on;
xlim([tmin,curTime]);
xlabel('Time (sec)');
ylabel('Inner Loop P (cmd) / Total (cmd)');
set(gca,'FontSize',16)
grid on;

subplot(2,3,5)
plot(curTime, iterm ,'bo','Linewidth',lw,'MarkerSize',ms);
hold on;
xlim([tmin,curTime]);
xlabel('Time (sec)');
ylabel('Inner Loop I (cmd)');
set(gca,'FontSize',16)
grid on;

subplot(2,3,6)
hold on;
plot(curTime, dterm ,'bo','Linewidth',lw,'MarkerSize',ms);
hold on;
xlim([tmin,curTime]);
xlabel('Time (sec)');
ylabel('Inner Loop D (cmd)');
set(gca,'FontSize',16)
grid on;
set(gcf, 'Units', 'Normalized', 'OuterPosition', [0, 0.04, 1, 0.96]);

end