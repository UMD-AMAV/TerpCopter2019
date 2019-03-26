function [thrustCmd, altErrorHistory] = altitudeController(gains, altErrorHistory, curTime, zcur, zd, altControlDegbugPublisher)


% Note thrustCmd valid range : []

% time elapsed since last control
dt = curTime - altErrorHistory.lastTime;

% unpack variables for convenience
outerLoopKp = gains.outerLoopKp*dt;
saturationLimit = gains.saturationLimit;
Kp = gains.Kp*dt;
Kd = gains.Kp*dt;
Ki = gains.Kp*dt;




%% Outer Loop Proportional Control on Altitude (Output Desired Alt Rate)

% control variable, current error in altitude (m)
altError = zd - zcur;

% P error
altRateDes = outerLoopKp*altError; % positive altError (below target) => increase thrust
altRateDes = max(min(altRateDes,saturationLimit),-saturationLimit); % saturate

%% Inner Loop PID Control on Altitude Rate (Output Thrust Command)

% control variable
altRateActual =  (zcur - altErrorHistory.alt) / dt;

% P error
altRateError = altRateDes - altRateActual; % positive (going up to slow) => increase thrust

% I error
altRateErrorIntegral = altErrorHistory.altRateErrorIntegral + (altRateError * dt);

% D error
prevAltRateError = altErrorHistory.altRateError; %
altRateErrorRate = ( altRateError  - prevAltRateError ) / dt;

% PID control
thrustCmdUnsat =  Kp * altRateError + ...
                  Kd * altRateErrorRate +  ...
                  Ki * altRateErrorIntegral;

% saturate so it is between -1 and 1
thrustCmd =  max(min(2,thrustCmdUnsat),0)-1;

%% pack up structure
altErrorHistory.lastTime = curTime;
altErrorHistory.altDes = zd;
altErrorHistory.alt = zcur;
altErrorHistory.altRateError = altRateError;
altErrorHistory.altRateErrorIntegral = altRateErrorIntegral;

%% display/debug







fprintf('Controller running at %3.2f Hz\n',1/dt);

displayFlag = 1;
if ( displayFlag )
    
    % initialize message to publish
    altControlDebugMsg = rosmessage(altControlDegbugPublisher);
    altControlDebugMsg.T = curTime;
    altControlDebugMsg.Zd = zd;
    altControlDebugMsg.Zcur = zcur;
    altControlDebugMsg.AltRateDes = altRateDes;
    altControlDebugMsg.AltRateActual = altRateActual;
    
    altControlDebugMsg.AltRateError = altRateError;
    altControlDebugMsg.AltRateErrorIntegral = altRateErrorIntegral;
    altControlDebugMsg.AltRateErrorRate = altRateErrorRate;
    
    
    altControlDebugMsg.Proportional = gains.Kp * altRateError;
    altControlDebugMsg.Integral = gains.Ki * altRateErrorIntegral;
    altControlDebugMsg.Derivative = gains.Kd * altRateErrorRate;

    altControlDebugMsg.ThrustCmdUnsat = thrustCmdUnsat;
    altControlDebugMsg.ThrustCmd = thrustCmd;
    
    send(altControlDegbugPublisher, altControlDebugMsg);
end

end