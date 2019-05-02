function [completionFlag, ayprCmd] = bhv_hover_over_H(stateEstimateMsg, ayprCmd, completion, bhvTime, hDetected, hAngle, hPixelX, hPixelY)
    
    % hDetected = 0 (no H detected) , 1 (H detected) 
    % hAngle = -180 to 180 (deg) 
    % hPixelX = -360 to 360 (pixels)
    % hPixelY = -640 to 640

    % unpack state estimate
    % pitch = stateEstimateMsg.PitchDegrees;
    % roll = stateEstimateMsg.RollDegrees;    
    % yaw = stateEstimateMsg.YawDegrees;
    
    
    % TODO: 
    % - add topic with H (x,y) data as input
    % - do some processing    
    if ( hDetected ) 
        % yawDesired = yaw + hAngle;
        pitchDesired = hPixelY;
        rollDesired = hPixelX;
%         time = bhvTime;
    else
        pitchDesired = 0;
        rollDesired = 0;
    end
    
    % set ayprCmd
    % - set ayprCmdMsg.PitchDesiredDegrees = 0;
    % ayprCmd.YawDesiredDegrees = yawDesired;
    ayprCmd.PitchDesiredDegrees = pitchDesired;
    ayprCmd.RollDesiredDegrees = rollDesired;
    
    % Terminating condition
    if bhvTime >= completion.durationSec
        completionFlag = 1;
        return;
    end
    completionFlag = 0;
end