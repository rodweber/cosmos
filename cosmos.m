%% the Science of the Operations of Mini Satellite fOrmations and Constellations
%% COSMOS V0.2
%% Main features:
%%  -LQR control
%%  -Euler angle aerodynamics
%%  -full GSI, SRP
%%
%% Revision history:
%%  -removed, GitHub commit messages are enough
%%
%% todo:
%%  -removed, will use GitHub ticketing system

%% Matlab parameters
clear all; close all;clc;format shortEng;format compact;
oldpath = path; path(oldpath,strcat('..',filesep,'matlabfunctions',filesep))
oldpath = path; path(oldpath,strcat('..',filesep,'cosmosSupport',filesep))

%% symbolic names of initial conditions and desired statevector functions
%sstInitialFunction=@IRSRendezvousInitial;
sstInitialFunction=@IvanovFormationFlightInitial;
%sstInitialFunction=@cluxterInitial;

%%----------------
%%----this is to produce figures for the paper----
%{
sunOn=1;
  altis=[450e3,450e3,550e3,550e3,650e3,650e3];
  altis=[450e3,450e3,650e3,650e3];
  %altis=[450e3,450e3,550e3,550e3];
  %altis=[500e3];
for alt=1:size(altis,2)
%% actual initial conditions of ODE
[sstTemp,ns,altitude,panels,rho,Tatmos,v,radiusOfEarth,meanMotion,mu,satelliteMass,panelSurface,...
  sstDesiredFunction,windOn,sunOn,deltaAngle,timetemp,totalTime,wakeAerodynamics,masterSatellite,...
  SSCoeff,inclination,SSParameters,meanAnomalyOffSet]=sstInitialFunction(altis(alt),sunOn); 
%}
%%----------------  

%% actual initial conditions of ODE
[sstTemp,ns,altitude,panels,rho,Tatmos,v,radiusOfEarth,meanMotion,mu,satelliteMass,panelSurface,...
  sstDesiredFunction,windOn,sunOn,deltaAngle,timetemp,totalTime,wakeAerodynamics,masterSatellite,...
  SSCoeff,inclination,SSParameters,meanAnomalyOffSet]=sstInitialFunction(); 
%%% meanMotion in [rad/s]

%% settings for control algorithm
[P,IR,A,B]=riccatiequation(meanMotion,SSCoeff);

%% non-gravitational perturbations
wind          =windOn*rho/2*v^2*[-1 0 0]'
sunlight      =sunOn *2*4.5e-6* [0 -1 0]'       %% for dusk-dawn orbit

%refsurf=panelSurface*panels(1);
refSurf=panelSurface*panels(3);

%% forcevector determination and its angular granulaty
alphas            =0:deltaAngle:360;     %% roll
betas             =0:deltaAngle:180;     %% pitch 
gammas            =0:deltaAngle:360;     %% yaw

aeropressureforcevector  =aeropressureforcevectorfunction(wind,panelSurface,panels(1),...
                               panels(2),panels(3),alphas,betas,gammas,rho,v,Tatmos);
solarpressureforcevector =solarpressureforcevectorfunction(sunlight,panelSurface,panels(1),...
                               panels(2),panels(3),alphas,betas,gammas);
                                                        
%% output of some key indicator for the amount of non-gravitational forces
%vecnorm(vecnorm(vecnorm(vecnorm(aeropressureforcevector))))
%vecnorm(vecnorm(vecnorm(vecnorm(solarpressureforcevector))))
%sum(aeropressureforcevector,'all')
%sum(solarpressureforcevector,'all')

%% features
stopUponTarget=0;               %% stop upon target conditions, use only for rendezvous
targetBox(1)=15;targetBox(2)=1;targetBox(3)=10;targetBox(4)=0.01;
stopUponRunAway=0;              %% stop upon target leaving proximity of desired trajectory box
runAwayBox(1)=1000;runAwayBox(2)=1000;runAwayBox(3)=1000;runAwayBox(4)=1000;

%% parameters for visualization
%! there are more parameters in the visualization function
VIS_DO            =0;           %% do you want to create a google Earth/kml file/vizualization ? 0-no 1-yes
VIS_SCALE         =100;         %% scales deployment, formation size
VIS_ACC_FACTOR    =60;          %% speeds up the Google Earth visualization
VIS_STEP          =60;          %% visualization step size in s
VIS_MODELFILENAME =strcat('figures',filesep,'cocu.dae');
VIS_FOOTPRINT     =0;           %% should a sensor footprint be shown?
VIS_US            =0;           %% should upper stage (US) be shown?
%% length of animation in min: totaltime/vis_step/accelerationfactor/60
fprintf('duration of movie without upper stage flight: %2.1f min\n',totalTime/VIS_ACC_FACTOR/60) 

%% solving the ODE in chunks per each control period
firstTime         =1;
currentTime       =0;           %% now, should usually be 0

%% some initializations
u             =zeros(3,ns);     %% control vector
e             =zeros(6,ns);     %% error vector
sst           =zeros(9,ns);     %% columns: statevector per each satellite
time          =0;               %% timevector with all steps
refPosChange  =zeros(3,1);
utemp         =zeros(3,ns,size(timetemp,2));
etemp         =zeros(6,ns,size(timetemp,2));
etempTransformed  =zeros(6,ns,size(timetemp,2));
refPosChangeTemp  =zeros(3,size(timetemp,2));
%% set sst for initial step right because only further steps are computed
sst(:,:,1)    =sstTemp(:,:,1);

while currentTime<totalTime
  %% Desired state vector
  for i=1:ns
    sstDesiredtemp(:,i,:)=sstDesiredFunction(currentTime+timetemp,meanMotion,i,1,SSCoeff,squeeze(SSParameters(:,i,1)),meanAnomalyOffSet);
  end
  %% apply disturbances
  %! disturbances  
  for j=1:size(timetemp,2)-1 %% control loop within ODE solver loop
    %% define transformation, requires momentary sunlight vector
    resultantForce=(wind+sunlight)/norm(wind+sunlight);
    angleResultantForce=atan2d(norm(cross([1 0 0],resultantForce)),dot([1 0 0],resultantForce));
    for i=1:ns %% compute error
      etemp(1:6,i,j)=sstTemp(1:6,i,j)-sstDesiredtemp(1:6,i,j);
    end
    for i=1:ns %% transform error
      etempTransformed(1:6,i,j)   =[rotz(angleResultantForce) zeros(3);zeros(3) rotz(angleResultantForce)]*etemp(1:6,i,j);        
    end
    if not(masterSatellite) %% if there is no master satellite, the error will be distributed
      averageErrorTransformed     =zeros(6,1);
      for i=1:ns %% compute average error
        averageErrorTransformed(:)=averageErrorTransformed(:)+etempTransformed(:,i,j)/ns;
      end      
      %for i=1:ns %% assign average error
      %  etempTransformed(2:6,i,j) =etempTransformed(2:6,i,j)-averageErrorTransformed(2:6);
      %end
    end %% if mastersatellite
      miniTransformed               =min(etempTransformed(1,:,j));
    for i=1:ns %% shift error
      etempTransformed(1,i,j)     =etempTransformed(1,i,j)-miniTransformed;
    end
    for i=1:ns %% retransform error
      etemp(:,i,j)    =[rotz(-angleResultantForce) zeros(3);zeros(3) rotz(-angleResultantForce)]*etempTransformed(1:6,i,j);
    end
    
    for i=1:ns %% solve ODE for each satellite
      [sstTemp(:,i,j+1),utemp(:,i,j+1)]=SSEquation(...
        IR,P,A,B,timetemp(j+1)-timetemp(j),sstTemp(:,i,j),etemp(:,i,j),...
        sqrt(wind(1)^2+wind(2)^2+wind(3)^2),sqrt(sunlight(1)^2+sunlight(2)^2+sunlight(3)^2),...
        alphas,betas,gammas,aeropressureforcevector,solarpressureforcevector,sstTemp(7,i,j),...
        sstTemp(8,i,j),sstTemp(9,i,j),refSurf,satelliteMass,wakeAerodynamics,masterSatellite,...
        currentTime+timetemp(j),radiusOfEarth,altitude,meanMotion);
    end
    refPosChangeTemp(1:3,j+1)=sstTemp(1:3,1,j+1)-sstTemp(1:3,1,j);
    %fprintf('\n--%f--%f',etemp(1,1,j),refPosChangeTemp(1,j+1))    
    for i=1:ns %% move coordinate system
      sstTemp(1:3,i,j+1)=sstTemp(1:3,i,j+1)-refPosChangeTemp(:,j+1);
    end
    %% this is to interrupt when a condition, i.e. proximity is achieved, don't use if you start in
    %% proximity as for instance for formation flight 
    if stopUponTarget && abs(sstTemp(1,2,j))<targetBox(1) && abs(sstTemp(2,2,j))<targetBox(2) &&...
       abs(sstTemp(3,2,j))<targetBox(3) && sqrt(sstTemp(4,2,j)^2+sstTemp(5,2,j)^2+sstTemp(6,2,j)^2)<targetBox(4)
      break;
    elseif stopUponRunAway && abs(sstTemp(1,2,j))>runAwayBox(1) && abs(sstTemp(2,2,j))>runAwayBox(2)...
           && abs(sstTemp(3,2,j))>runAwayBox(3) && sqrt(sstTemp(4,2,j)^2+sstTemp(5,2,j)^2+sstTemp(6,2,j)^2)>runAwayBox(4)
      break;
    end
  end  %% end of control loop

  if firstTime==1 %% set sst for initial step right because only further steps are computed
    sst(:,:,1)  =sstTemp(:,:,1);
    firstTime   =0;
  end
  
  %% initial conditions for next control loop, j==1 is not used from here (except for e)
  sstTemp(:,:,1)=sstTemp(:,:,end);
 
  %fprintf('\n');
  %% append data of last control loop to global data vector
  sst         =cat(3,sst,sstTemp(:,:,2:end));  
  u           =cat(3,u,utemp(:,:,2:end));   
  refPosChange=cat(2,refPosChange,refPosChangeTemp(:,2:end));
  e           =cat(3,e,etemp(:,:,1:end-1));
  time        =[time ; currentTime+timetemp(2:end)'];  
  %% print progress of iterations to screen
  if currentTime>0
    fprintf('\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b')
  end
  currentTime=time(end);
  fprintf('simulated time %5.0f/%5.0f min (%3.0f%%)', currentTime/60, totalTime/60,currentTime/totalTime*100);

  if stopUponTarget && abs(sstTemp(1,2,j))<targetBox(1) && abs(sstTemp(2,2,j))<targetBox(2) &&...
     abs(sstTemp(3,2,j))<targetBox(3) && sqrt(sstTemp(4,2,j)^2+sstTemp(5,2,j)^2+sstTemp(6,2,j)^2)<targetBox(4)
    break;
  elseif stopUponRunAway && abs(sstTemp(1,2,j))>runAwayBox(1) && abs(sstTemp(2,2,j))>runAwayBox(2)...
         && abs(sstTemp(3,2,j))>runAwayBox(3) && sqrt(sstTemp(4,2,j)^2+sstTemp(5,2,j)^2+sstTemp(6,2,j)^2)>runAwayBox(4)
      break;
  end
  %{
  for i=1:ns
    plot3(squeeze(sst(1,i,:)),squeeze(sst(2,i,:)),squeeze(sst(3,i,:)),'-');hold on
    names(i)=[{strcat('sat',int2str(i))}];
  end
  xlabel('X [m]');ylabel('Y [m]');zlabel('Z [m]');legend(names);grid on;hold off;axis equal;
  pause(0.001)
  %}
end %% global while/time loop


%----------------
%%----this is to produce figures for the paper----
%{
if alt==1
  displayY=zeros(size(altis,2),ns,size(sst,3));
  ealt=zeros(size(altis,2),3,ns,size(sst,3));
end
for i=1:ns
  for j=1:size(sst,3)
    displayY(alt,i,j)=sst(2,i,j);
    ealt(alt,:,i,j)=e(1:3,i,j);
  end
end
sunOn=1-sunOn;

end
if 0 %% plot Y for different altitudes and sunOn and sunOff
  sunOn=1;
  ax = axes;
  hold on;
  numberOfColors = length(ax.ColorOrder);
  ax.ColorOrderIndex = 1;
  %figure;
  for i=1:size(altis,2)
    Q=plot(time/2/pi*meanMotion,squeeze(displayY(i,2,:))); %% plot y-movement of 2nd satellite
    hold on
    if sunOn
      ax.ColorOrderIndex = mod(ax.ColorOrderIndex-2,numberOfColors)+1; % keep same color
      %Q.ColorOrderIndex = Q.ColorOrderIndex-1
    else
      Q.LineStyle='--';
    end
    legendnames(i)={strcat('Y',num2str(altis(i)),int2str(sunOn))};    
    %legend('x','y','z');title('reference position change')
    sunOn=1-sunOn;
  end
  legend(legendnames);
  hold off;  
end

if 1 %% plot e for different altitudes and sunOn and sunOff
  sunOn=1;
  ax1 = axes;
  hold on;
  numberOfColors = length(ax1.ColorOrder);
  ax1.ColorOrderIndex = 1;
  figure
  subplot(5,1,1)
  for i=1:size(altis,2)
    %Q1=plot(time,squeeze(ealt(i,1,1,:)),time,squeeze(ealt(i,1,2,:)),time,squeeze(ealt(i,1,3,:))); %% plot e of 2nd satellite
    Q1=plot(time/2/pi*meanMotion,squeeze(ealt(i,1,2,:))); %% plot e of 2nd satellite
    hold on
    if sunOn
      ax1.ColorOrderIndex = mod(ax1.ColorOrderIndex-2,numberOfColors)+1; % keep same color
      %Q1.ColorOrderIndex = Q1.ColorOrderIndex-1
    else
      %Q1.LineStyle='--';
    end
    legendnames(i)={strcat('e',num2str(altis(i)),int2str(sunOn))};    
    %legend('x','y','z');title('reference position change')
    sunOn=1-sunOn;
  end
  legend(legendnames);
  
  sunOn=1;
  ax2 = axes;
  hold on;
  numberOfColors = length(ax2.ColorOrder);
  ax2.ColorOrderIndex = 1;
  subplot(5,1,2)
  for i=1:size(altis,2)
    %Q2=plot(time,squeeze(ealt(i,2,1,:)),time,squeeze(ealt(i,2,2,:)),time,squeeze(ealt(i,2,3,:))); %% plot e of 2nd satellite
    Q2=plot(time/2/pi*meanMotion,squeeze(ealt(i,2,2,:))); %% plot e of 2nd satellite
    hold on
    if sunOn
      %ax2.ColorOrderIndex = mod(ax2.ColorOrderIndex-2,numberOfColors)+1; % keep same color
      %Q2.ColorOrderIndex = Q2.ColorOrderIndex-1
    else
      %Q2.LineStyle='--';
    end
    sunOn=1-sunOn;
  end
  
  sunOn=1;
  ax3 = axes;
  hold on;
  numberOfColors = length(ax3.ColorOrder);
  ax3.ColorOrderIndex = 1;
  subplot(5,1,3)
  for i=1:size(altis,2)
    %Q3=plot(time,squeeze(ealt(i,3,1,:)),time,squeeze(ealt(i,3,2,:)),time,squeeze(ealt(i,3,3,:))); %% plot e of 2nd satellite
    Q3=plot(time/2/pi*meanMotion,squeeze(ealt(i,3,2,:))); %% plot e of 2nd satellite
    hold on
    if sunOn
      %ax3.ColorOrderIndex = mod(ax3.ColorOrderIndex-2,numberOfColors)+1; % keep same color
      %Q3.ColorOrderIndex = Q3.ColorOrderIndex-1
    else
      %Q3.LineStyle='--';
    end
    sunOn=1-sunOn;
  end
  hold off;  

  sunOn=1;
  ax4 = axes;
  hold on;
  numberOfColors = length(ax4.ColorOrder);
  ax4.ColorOrderIndex = 1;
  subplot(5,1,4)
  for i=1:size(altis,2)
    %Q3=plot(time,squeeze(ealt(i,3,1,:)),time,squeeze(ealt(i,3,2,:)),time,squeeze(ealt(i,3,3,:))); %% plot e of 2nd satellite
    Q4=plot(time/2/pi*meanMotion,squeeze(sum(ealt(i,1:3,2,:)))); %% plot e of 2nd satellite
    hold on
    if sunOn
      %ax4.ColorOrderIndex = mod(ax3.ColorOrderIndex-2,numberOfColors)+1; % keep same color
      %Q4.ColorOrderIndex = Q3.ColorOrderIndex-1
    else
      %Q4.LineStyle='--';
    end
    sunOn=1-sunOn;
  end
  hold off;  

  sunOn=1;
  ax5 = axes;
  hold on;
  numberOfColors = length(ax5.ColorOrder);
  ax5.ColorOrderIndex = 1;
  subplot(5,1,5)
  for i=1:size(altis,2)
    %Q3=plot(time,squeeze(ealt(i,3,1,:)),time,squeeze(ealt(i,3,2,:)),time,squeeze(ealt(i,3,3,:))); %% plot e of 2nd satellite
    Q5=plot(time/2/pi*meanMotion,squeeze(sum(sum(ealt(i,1:3,:,:))))); %% plot e of 2nd satellite
    hold on
    if sunOn
      %ax4.ColorOrderIndex = mod(ax3.ColorOrderIndex-2,numberOfColors)+1; % keep same color
      %Q4.ColorOrderIndex = Q3.ColorOrderIndex-1
    else
      %Q4.LineStyle='--';
    end
    sunOn=1-sunOn;
  end
  hold off;  
end

return
%}
%----------------


%% results' plotting
plotting(sst(7:9,:,:),sst(1:6,:,:),refPosChange,time,ns,meanMotion,u,e);
pause(5);

%% convert from classical ZYZ Euler angles to Google Earth Euler angles ZYX
anglesGE=sst(7:9,:,:);
for j=1:size(anglesGE,3)
  for i=1:ns
    rotm            =eul2rotm(anglesGE(:,i,j)'/180*pi,'ZYZ');
    anglesGE(:,i,j) =rotm2eul(rotm,'ZYX')'/pi*180;
  end
end

%% map on globe and create kml file
if VIS_DO
  if masterSatellite %% if a master satellite is used extend variables accordingly
                      %% actually is only valid for passive master satellite
    ns=ns+1;
    sst         =cat(2,sst,zeros(size(sst,1),1,size(sst,3))); 
    anglesGE    =cat(2,anglesGE,zeros(size(anglesGE,1),1,size(anglesGE,3))); 
    VIS_MASTERFILENAME="figures/iss.dae";
  else
    VIS_MASTERFILENAME="";
  end
  
  if inclination~=90
    fprintf('\n warning Visualization does not yet account for inclinations unequal 90 deg\n');
  end
  
  visualization(ns,time,VIS_SCALE*sst(1,:,:),VIS_SCALE*sst(2,:,:),VIS_SCALE*sst(3,:,:),altitude,anglesGE, VIS_MODELFILENAME,VIS_MASTERFILENAME,radiusOfEarth,mu,VIS_STEP,VIS_ACC_FACTOR,VIS_FOOTPRINT,VIS_US)
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


function visualization(ns,ttime,sstx,ssty,sstz,altitude,anglesGE,modelfilename,masterfilename,radiusOfEarth,mu,vis_step,accelerationfactor,footprintyn,USyn)
  %% this function adds the global movement of the satellite based on Kepler's laws
  %this function works with km instead of m %!harmonize

  dimsst = size(sstx);
  sstx = reshape(sstx,[dimsst(2:end) 1]);
  ssty = reshape(ssty,[dimsst(2:end) 1]);
  sstz = reshape(sstz,[dimsst(2:end) 1]);

  
  
  RE = radiusOfEarth/1000;          % Earth's radius                            [km]
  muE = mu/1e9;    % Earth gravitational parameter             [km^3/sec^2]
  wE = (2*pi/86164);  % Earth rotation velocity aorund z-axis     [rad/sec]
  %% ORBIT INPUT
  RAAN=0; %%RAAN    = input(' Right Ascension of Ascendent Node    [  0,360[    RAAN   [deg] = ');    
  w=0;    %%w       = input(' Argument of perigee                  [  0,360[    w      [deg] = ');
  v0=0;   %%v0      = input(' True anomaly at the departure        [  0,360[    v0     [deg] = ');
  inclination=89.999999;%i       = input(' Inclination                          [-90, 90]    i      [deg] = ');
  a=RE+altitude/1000;%a       = input(' Major semi-axis                       (>6378)     a      [km]  = ');
  ecc_max = sprintf('%6.4f',1-RE/a);     % maximum value of eccentricity allowed
  e=0;%e       = input([' Eccentricity                         (<',ecc_max,')    e            = ']);
  RAAN  = RAAN*pi/180;        % RAAN                          [rad]
  w     = w*pi/180;           % Argument of perigee           [rad]
  v0    = v0*pi/180;          % True anomaly at the departure [rad]
  inclination     = inclination*pi/180;           % inclination                   [rad]
  %% ORBIT COMPUTATION
  rp = a*(1-e);               % radius of perigee             [km]
  ra = a*(1+e);               % radius of apogee              [km]
  Vp = sqrt(muE*(2/rp-1/a));  % velocity at the perigee       [km/s]
  Va = sqrt(muE*(2/ra-1/a));  % velocity at the  apogee       [km/s]
  n  = sqrt(muE./a^3);        % mean motion                   [rad/s]
  p  = a*(1-e^2);             % semi-latus rectus             [km]
  T  = 2*pi/n;                % period                        [s]
  h  = sqrt(p*muE);           % moment of the momentum        [km^2/s]
  h1 = sin(inclination)*sin(RAAN);      % x-component of unit vector h
  h2 = -sin(inclination)*cos(RAAN);     % y-component of unit vector h
  h3 = cos(inclination);                % z-component of unit vector h
  n1 = -h2/(sqrt(h1^2+h2^2)); % x-component of nodes' line
  n2 =  h1/(sqrt(h1^2+h2^2)); % y-component of nodes' line
  n3 = 0;                     % z-component of nodes' line
  N  = [n1,n2,n3];            % nodes' line (unit vector)
  %% PRINT SOME DATAS
  hours   = floor(T/3600);                   % hours   of the orbital period
  minutes = floor((T-hours*3600)/60);        % minutes of the orbital period
  seconds = floor(T-hours*3600-minutes*60);  % seconds of the orbital period
  t0   = ttime(1);                           % initial time          [s]
  tf=ttime(end);                             % final time
  vis_step=2;       %step = input(' Time step.        [s] step = ');  % time step             [s]    
  t    = t0:vis_step:tf;                          % vector of time        [s] 
  %% DETERMINATION OF THE DYNAMICS
  cosE0 = (e+cos(v0))./(1+e.*cos(v0));               % cosine of initial eccentric anomaly
  sinE0 = (sqrt(1-e^2).*sin(v0))./(1+e.*cos(v0));    %   sine of initial eccentric anomaly
  E0 = atan2(sinE0,cosE0);                           % initial eccentric anomaly              [rad]
  if (E0<0)                                          % E0€[0,2pi]
    E0=E0+2*pi;
  end
  tp = (-E0+e.*sin(E0))./n+t0;                       % pass time at the perigee               [s]
  M  = n.*(t-tp);                                    % mean anomaly                           [rad]
  %% Mk = Ek - e*sin(Ek);
  % Eccentric anomaly (must be solved iteratively for Ek)
  E = zeros(size(t,2),1);
  for j=1:size(t,2)
    E(j) = anom_ecc(M(j),e);                     % eccentric anomaly         [rad]
  end
  %% True anomaly, Argument of latitude, Radius
  sin_v = (sqrt(1-e.^2).*sin(E))./(1-e.*cos(E));   % sine of true anomaly
  cos_v = (cos(E)-e)./(1-e.*cos(E));               % cosine of true anomaly
  v     = atan2(sin_v,cos_v);                      % true anomaly              [rad]
  theta = v + w;                                   % argument of latitude      [rad]
  r     = (a.*(1-e.^2))./(1+e.*cos(v));            % radius                    [km]
  %% Satellite coordinates
  % "Inertial" reference system ECI (Earth Centered Inertial)
  xp = r.*cos(theta);                          % In-plane x position (node direction)             [km]
  yp = r.*sin(theta);                          % In-plane y position (perpendicular node direct.) [km]
  xs = xp.*cos(RAAN)-yp.*cos(inclination).*sin(RAAN);    % ECI x-coordinate SAT                             [km]
  ys = xp.*sin(RAAN)+yp.*cos(inclination).*cos(RAAN);    % ECI y-coordinate SAT                             [km]
  zs = yp.*sin(inclination);                             % ECI z-coordinate SAT                             [km]
  rs = p./(1+e.*cos(theta-w));                 % norm of radius SAT                               [km]
  %% GREENWICH HOUR ANGLE
  disp(' From ephemeridis you can reach the greenwich hour angle at the epoch and reset it from Aries'' point');
  disp(' Ephemeridis Almanac: http://www.nauticalalmanac.it/it/astronomia-nautica/effemeridi-nautiche.html ');
  % Greenwich hour angle è l'orientamento della Terra relativo al punto di
  % Ariete in un'epoca precisa. Tale valore è tabulato per ogni giorno
  % dell'anno, ogni ora, minuto ecc. nelle effemeridi che si possono trovare
  % negli almanacchi nautici in generale. Se non lo si conosce, o si intende
  % fare un'analisi approssimativa  è consigliabile immettere 0 in modo da
  % far coincidere il punto di ariete con Greenwich all'epoca.
  %greenwich0 = input(' Insert Greenwich longitude respect to the vernal axis. GHA [deg] = ');
  greenwich0=0;
  %% SUB-SATELLITE-POINT
  greenwich0 = greenwich0*pi/180;                 % Greenwich hour angle at the initial time    [rad]
  rot_earth  = wE.*(t-t0)+greenwich0;             % Greenwich hour angle at the time t          [rad]
  for j=1:size(t,2)
    if rot_earth(j) < (-pi)
      nn = ceil(rot_earth(j)/(-2*pi));
      rot_earth(j) = rot_earth(j) + nn*2*pi;
    elseif rot_earth(j) > (pi)
      nn = fix(rot_earth(j)/(2*pi));
      rot_earth(j) = rot_earth(j) - nn*2*pi;
    end
  end
  %% interpolate relative position on visualization grid
  for j=1:ns
    sstxvgrid(j,:)=interp1(ttime,sstx(j,:),t);
    sstyvgrid(j,:)=interp1(ttime,ssty(j,:),t);
    sstzvgrid(j,:)=interp1(ttime,sstz(j,:),t);
    zaxvgrid(j,:)=interp1(ttime,squeeze(anglesGE(1,j,:)),t);
    yaxvgrid(j,:)=interp1(ttime,squeeze(anglesGE(2,j,:)),t);
    xaxvgrid(j,:)=interp1(ttime,squeeze(anglesGE(3,j,:)),t);
  end
  footprintsize=zeros(size(t,2),1);
  if footprintyn
    for i=1:size(t,2)
      %for j=1:ns
        %MAXY=sqrt(max(sstxvgrid(j,i)^2+sstyvgrid(j,i)^2));
      %end
      MAXY=abs(sstyvgrid(2,i));
      %footprintsize(i)=MAXY*1e2;%round(  MAXY/10^floor(log10(MAXY)) )  *  1e4;
      footprintsize(i)=(200000-10000)/2000*MAXY+10000;%round(  MAXY/10^floor(log10(MAXY)) )  *  1e4;
    end
  end
  %% centerpoint
  Lat(1,:)     =  asin(sin(inclination).*sin(theta))/pi*180;              % Latitude             [deg]
  Long(1,:)    = (atan2(ys./rs,xs./rs)-rot_earth')/pi*180;    % Longitude            [deg]
  rs2(1,:)         = rs;                                        % radius                [km]
  %% satellites
  for j=1:ns
    latoff(j,:)      = asin(  sstxvgrid(j,:)/1000  ./  (rs(:,1)'  + sstzvgrid(j,:)/1000) ); %%latitude offset
    longoff(j,:)     = asin( sstyvgrid(j,:)/1000   ./   (rs(:,1)' + sstzvgrid(j,:)/1000) ); %%longitude offset
  end
  for i=1:size(t,2)-1
      for j=2:ns+1
        if i==1 %% 1-point, northward
            Lat(j,i)     = Lat(1,i)+latoff(j-1,i)/pi*180;      % Latitude             [deg]
            Long(j,i)    = Long(1,i)+longoff(j-1,i)/pi*180;    % Longitude            [deg]
            rs2(j,i)     = rs(i)'+sstzvgrid(j-1,i)/1000;       % radius                [km]
        elseif Lat(1,i+1)>Lat(1,i) %% northward
            Lat(j,i)     = Lat(1,i)+latoff(j-1,i)/pi*180;      % Latitude             [deg]
            Long(j,i)    = Long(1,i)+longoff(j-1,i)/pi*180;    % Longitude            [deg]
            rs2(j,i)     = rs(i)'+sstzvgrid(j-1,i)/1000;       % radius                [km]
        elseif Lat(1,i+1)<Lat(1,i) %% southward
            Lat(j,i)     = Lat(1,i)-latoff(j-1,i)/pi*180;      % Latitude             [deg]
            Long(j,i)    = Long(1,i)+longoff(j-1,i)/pi*180;    % Longitude            [deg]
            rs2(j,i)     = rs(i)'+sstzvgrid(j-1,i)/1000;       % radius                [km]
            zaxvgrid(j-1,i)= zaxvgrid(j-1,i)-180;
        elseif i==size(t,2) %% last point
            if Lat(1,i)>Lat(1,i-1) %% northward
                Lat(j,i)     = Lat(1,i)+latoff(j-1,i)/pi*180;      % Latitude             [deg]
                Long(j,i)    = Long(1,i)+longoff(j-1,i)/pi*180;    % Longitude            [deg]
                rs2(j,i)     = rs(i)'+sstzvgrid(j-1,i)/1000;       % radius                [km]
            elseif Lat(1,i)<Lat(1,i-1) %% southward
                Lat(j,i)     = Lat(1,i)-latoff(j-1,i)/pi*180;      % Latitude             [deg]
                Long(j,i)    = Long(1,i)-longoff(j-1,i)/pi*180;    % Longitude            [deg]
                rs2(j,i)     = rs(i)'+sstzvgrid(j-1,i)/1000;       % radius                [km]
            end
        else
            fprintf('error708422')
        end
      end
  end
figure
      subplot(4,1,1)
      for j=1:ns
        plot(t/3600,sstxvgrid(j,:))
        hold on
      end
      ylabel('x [m]');xlabel('time [h]');grid on;hold off
      subplot(4,1,2)
      for j=1:ns
        plot(t/3600,sstyvgrid(j,:))
        hold on
      end
      ylabel('y [m]');xlabel('time [h]');grid on;hold off
      subplot(4,1,3)
      for j=1:ns
        plot(t/3600,sstzvgrid(j,:))
        hold on
      end
      ylabel('z [m]');xlabel('time [h]');grid on;hold off
      subplot(4,1,4)
      for j=1:ns
        plot(t/3600,footprintsize)
        hold on
      end
      ylabel('footprint [m]');xlabel('time [h]');grid on;hold off
      
%  figure
%      subplot(2,1,1)
%      for j=1:ns
%        plot(t,ii(j,:))
%        hold on
%      end
%      ylabel("-");
%      subplot(2,1,2)
%      for j=1:ns
%        plot(t,ll(j,:))
%        hold on
%      end
%      ylabel("-");
   figure
      subplot(3,1,1)
      for j=1:ns+1
%        plot(t/3600,Lat(j,:),t/3600,footprintsize/3e4,t/3600,sstyvgrid(2,:)/50)
        hold on
      end
      ylabel("Lat");
      subplot(3,1,2)
      for j=1:ns+1
        plot(t/3600,Long(j,:))
        hold on
      end
      ylabel("Long");
      subplot(3,1,3)
      for j=1:ns+1
        plot(t,rs2(j,:))
        hold on
      end
      ylabel("rs2");
      
  %% write KML file
  writeKML(Lat,Long,rs2,t,ns,zaxvgrid,yaxvgrid,xaxvgrid,modelfilename,masterfilename,footprintsize,accelerationfactor,footprintyn,USyn)
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function writeKML(Lat,Long,rs,t,ns,zaxvgrid,yaxvgrid,xaxvgrid,modelfilename,masterfilename,footprintsize,accelerationfactor,footprintyn,USyn)
%function writeKML(Lat,Long,rs,t,ns,angles,modelfilename)
  %! simulation cannot be longer than a day
  %! why division by 60 twice?
  %! can do only inclination=90 deg
  %! the kml tour follows virtual center satellite
  initialtime=datenum('2021-06-13T00:00:00Z','yyyy-mm-ddTHH:MM:SSZ');
  poletransition=0;
  latviewoffset=1;
  longviewoffset=-1;
  tiltview=25;
  altitudeview=600000;%600000;
  headingviewoffset=30;
  modelscalex=2000;
  modelscaley=2000;
  modelscalez=2000;
  vis_duration=1;
  
  tourjumpduration=zeros(1,size(t,2));
  tourjumpduration(2:end)=(t(2:end)-t(1:end-1))/accelerationfactor;
  filename='cosmos.kml';
  USpoints=300;
  %{  
  for iiii=1:1
    counter=0;
    counter2=0;
    %% add pole points
    for i=2:size(t,2)-1
      counter2=counter2+1;
      if counter~=0&&counter2==3
        counter=0;
        counter2=0;
      end
      if Lat(1,i)==max([Lat(1,i-1) Lat(1,i) Lat(1,i+1)]) %% around northpole
        %for j=1:ns+1
          %if abs(Long(j,i))-abs(Long(j,i-1))<abs(Long(j,i))-abs(Long(j,i+1)) %% before northpole
          %  fprintf('beforenp')
          %elseif abs(Long(j,i))-abs(Long(j,i-1))>abs(Long(j,i))-abs(Long(j,i+1)) && counter==0%% after northpole
            %printf('\nafternp\n')
            counter=counter+1;
            %% add line to Lat,Long,t, tourjumpduration
            Lat(:,i+1:end+1)=Lat(:,i:end);
            Long(:,i+1:end+1)=Long(:,i:end);
            rs(:,i+1:end+1)=rs(:,i:end);
            t(i+1:end+1)=t(i:end);
            tourjumpduration(i+1:end+1)=tourjumpduration(i:end);
            angles(:,:,i+1:end+1)=angles(:,:,i:end);
            footprintsize(i+1:end+1)=footprintsize(i:end);
            %% assign data to new line
            Lat(:,i)=(Lat(:,i-1)+Lat(:,i+1))/2; %!interpolate
            for k=1:ns+1                      
              %idx=find(min(   [abs(Lat(k,i-1)) abs(Lat(k,i+1))]   )==Lat(k,:));
              %Long(k,i)=(  Long(k,i-1)+Long(k,i+1)+sign(Long(k,idx))*180  )/2;
              if (sign(Long(k,i-1))~=sign(Long(k,i+1)) )&& ( abs(Long(k,i-1)) + abs(Long(k,i+1)) > 100 )
                Long(k,i)=(  Long(k,i-1) + Long(k,i+1) - 2*sign(max([abs(Long(k,i-1)) abs(Long(k,i+1)) ])) * max([abs(Long(k,i-1)) abs(Long(k,i+1)) ])  )/2;
                  Long(k,i)
                  Long(k,i-1)
                  Long(k,i+1)
                
              else
                  Long(k,i)=(  Long(k,i-1) + Long(k,i+1))/2;
              end
    
            end
            t(i)=(t(i)+t(i-1))/2;
            milliseconds=round(1000*(initialtime*24*60*60+t(i)-floor(initialtime*24*60*60+t(i))));
            strcat(datestr(initialtime+t(i)/24/60/60,29),'T',datestr(initialtime+t(i)/24/60/60,13),'.',num2str(milliseconds),'Z')
            iiii
            input('aa')            
            tourjumpduration(i)=tourjumpduration(i)/2;
            tourjumpduration(i+1)=tourjumpduration(i);
            angles(:,:,i)=(angles(:,:,i-1)+angles(:,:,i+1))/2;
            footprintsize(i)=(footprintsize(i-1)+footprintsize(i+1))/2;
            %{
            %% x add further line to Lat,Long,t, tourjumpduration
            Lat(:,i+3:end+1)=Lat(:,i+2:end);
            Long(:,i+3:end+1)=Long(:,i+2:end);
            rs(:,i+3:end+1)=rs(:,i+2:end);
            t(i+3:end+1)=t(i+2:end);
            tourjumpduration(i+3:end+1)=tourjumpduration(i+2:end);
            angles(:,:,i+3:end+1)=angles(:,:,i+2:end);
            footprintsize(i+3:end+1)=footprintsize(i+2:end);
            %% x assign data to new further line
            Lat(:,i+2)=(Lat(:,i+1)+Lat(:,i+3))/2; %!interpolate
            for k=1:ns+1                      
              %idx=find(min(   [abs(Lat(k,i+1)) abs(Lat(k,i+3))]   )==Lat(k,:));
              %Long(k,i+2)=(  Long(k,i+1)+Long(k,i+3)+sign(Long(k,idx))*180  )/2;
              if (sign(Long(k,i+1))~=sign(Long(k,i+3)) )&& ( abs(Long(k,i+1)) + abs(Long(k,i+3)) > 100 )
                Long(k,i)=(  Long(k,i+1) + Long(k,i+3) - 2*sign(max([abs(Long(k,i+1)) abs(Long(k,i+3)) ])) * max([abs(Long(k,i+1)) abs(Long(k,i+3)) ])  )/2;
              else
                Long(k,i)=(  Long(k,i+1) + Long(k,i+3))/2;
              end
            end
            t(i+2)=(t(i+2)+t(i+1))/2;
            tourjumpduration(i+2)=tourjumpduration(i+2)/2;
            tourjumpduration(i+3)=tourjumpduration(i+2);
            angles(:,:,i+2)=(angles(:,:,i+1)+angles(:,:,i+3))/2;
            footprintsize(i+2)=(footprintsize(i+1)+footprintsize(i+3))/2;
            %}
          %end
        %end
      elseif Lat(1,i)==min([Lat(1,i-1) Lat(1,i) Lat(1,i+1)]) %% around southpole
        fprintf('do something for the southpole point adding')
      end
    end
  end
  %}
  for i=1:size(t,2) %% shift longitude from 0-360 deg to +/- 180
    for j=1:ns+1
      if Long(j,i)<-180
        Long(j,i)=Long(j,i)+360;
      end
    end
  end 
  %%upper stage data
  USLong=[-flip(Long(1,2:USpoints))'; Long(1,1:USpoints)'];
  USLat=[-flip(Lat(1,2:USpoints))'; Lat(1,1:USpoints)'];
  USrs=[flip(rs(1,2:USpoints))'; rs(1,1:USpoints)'];
  UStime=[-flip(t(2:USpoints)) t(1:USpoints)];
  USjumpduration=(t(2)-t(1))/accelerationfactor*2;
  %a=input('a')
  
  id=fopen(filename,'w'); %% write kml file
  fprintf(id,'<?xml version="1.0" encoding="UTF-8"?><kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2">');
  fprintf(id,'\n<Folder> ');
  fprintf(id,'\n  <Style id="stylesel_0"><IconStyle><Icon><href></href></Icon></IconStyle><LabelStyle><scale>0</scale></LabelStyle></Style>');

  %% initial camera viewpoint
%  fprintf(id,'\n<Camera>');
%  fprintf(id,'\n  <gx:TimeSpan>');
%  fprintf(id,'\n		<begin>%s</begin><end>%s</end>',strcat(datestr(initialtime-1/24/60/60,29),'T',datestr(initialtime-1/24/60/60,13),'Z'),strcat(datestr(initialtime+1/24/60/60,29),'T',datestr(initialtime+1/24/60/60,13),'Z'));
%  fprintf(id,'\n  </gx:TimeSpan>');
%  fprintf(id,'\n  <longitude>%f</longitude><latitude>%f</latitude><altitude>%f</altitude>',Long(1,1)+longviewoffset*(90-abs(Lat(1,1) ))/90,Lat(1,1)-latviewoffset,altitudeview);
%  fprintf(id,'\n  <heading>%f</heading><tilt>%f</tilt><roll>0</roll>',headingviewoffset*(90-abs(Lat(1,1) ))/90,tiltview);
%  fprintf(id,'\n</Camera>');

  fprintf(id,'\n<Camera>');
  fprintf(id,'\n   <gx:TimeSpan><begin>%s</begin><end>%s</end></gx:TimeSpan>',strcat(datestr(initialtime+UStime(1)/24/60/60-1/24/60/60,29),'T',datestr(initialtime+UStime(1)/24/60/60-1/24/60/60,13),'Z'),strcat(datestr(initialtime+UStime(1)/24/60/60+1/24/60/60,29),'T',datestr(initialtime+UStime(1)/24/60/60+1/24/60/60,13),'Z'));
  fprintf(id,'\n   <longitude>%f</longitude><latitude>%f</latitude><altitude>%f</altitude>',USLong(1)+longviewoffset*(90-abs(USLat(1) ))/90,USLat(1)-latviewoffset,altitudeview);
  fprintf(id,'\n   <heading>%f</heading><tilt>%f</tilt><roll>0</roll>',headingviewoffset*(90-abs(USLat(1) ))/90,tiltview);
  fprintf(id,'\n</Camera>');

  %% tour definition

  fprintf(id,'\n<gx:Tour><name>Play me!</name><gx:Playlist>');
  for i=(-USpoints+1):1:size(t,2)-1
    if i<USpoints
      fprintf(id,'\n<gx:FlyTo><gx:flyToMode>smooth</gx:flyToMode><gx:duration>%f</gx:duration><Camera>',USjumpduration);
      pointintime=strcat(datestr(initialtime+UStime(i+USpoints)/24/60/60,29),'T',datestr(initialtime+UStime(i+USpoints)/24/60/60,13),'Z');
      pointintimeb=strcat(datestr(initialtime+UStime(i+USpoints)/24/60/60-vis_duration/24/60/60,29),'T',datestr(initialtime+UStime(i+USpoints)/24/60/60-vis_duration/24/60/60,13),'Z');
      pointintimee=strcat(datestr(initialtime+UStime(i+USpoints)/24/60/60+vis_duration/24/60/60,29),'T',datestr(initialtime+UStime(i+USpoints)/24/60/60+vis_duration/24/60/60,13),'Z');
      %fprintf(id,'\n		    <gx:TimeStamp><when> %s </when></gx:TimeStamp>',pointintime');
      fprintf(id,'\n  <gx:TimeSpan><begin>%s</begin><end>%s</end></gx:TimeSpan>',pointintimeb,pointintimee);
      %% set viewpoint and heading to according to flight direction
      if i==-USpoints+1  %% first point
        fprintf(id,'\n  <longitude>%f</longitude><latitude>%f</latitude><altitude>%f</altitude>',USLong(i+USpoints)+longviewoffset*(90-abs(USLat(1,1) ))/90,USLat(i+USpoints)-latviewoffset,altitudeview);
        fprintf(id,'\n  <heading>%f</heading><tilt>%f</tilt><roll>0</roll>',headingviewoffset*(90-abs(USLat(1,1) ))/90,tiltview);
      elseif USLat(i+USpoints)-USLat(i-1+USpoints)>=0 %% northern direction
        fprintf(id,'\n  <longitude>%f</longitude><latitude>%f</latitude><altitude>%f</altitude>',USLong(i+USpoints)+longviewoffset*(90-abs(USLat(i+USpoints,1) ))/90,USLat(i+USpoints)-latviewoffset,altitudeview);
        fprintf(id,'\n  <heading>%f</heading><tilt>%f</tilt><roll>0</roll>',headingviewoffset*(90-abs(USLat(i+USpoints,1) ))/90,tiltview);
      elseif USLat(i+USpoints)-USLat(i-1+USpoints)<0  %% southern direction
        %printf('\nUSsd%d',i)
        fprintf(id,'\n  <longitude>%f</longitude><latitude>%f</latitude><altitude>%f</altitude>',USLong(i+USpoints+1)-longviewoffset*(90-abs(USLat(1,1) ))/90,USLat(i+USpoints+1)+latviewoffset,altitudeview);
        fprintf(id,'\n  <heading>%f</heading><tilt>%f</tilt><roll>0</roll>',180+headingviewoffset*(90-abs(USLat(1,1) ))/90,tiltview);
      else
        fprintf('error')
      end
      fprintf(id,'\n</Camera></gx:FlyTo>');   
    elseif i==USpoints
      ;
    else %% not USpoints anymore
    fprintf(id,'\n<gx:FlyTo><gx:flyToMode>smooth</gx:flyToMode><gx:duration>%f</gx:duration><Camera>',tourjumpduration(i));
    milliseconds=round(1000*(initialtime*24*60*60+t(i)-floor(initialtime*24*60*60+t(i))));
    pointintime=strcat(datestr(initialtime+t(i)/24/60/60,29),'T',datestr(initialtime+t(i)/24/60/60,13),'.',num2str(milliseconds),'Z');
    pointintimeb=strcat(datestr(initialtime+t(i)/24/60/60-vis_duration/24/60/60,29),'T',datestr(initialtime+t(i)/24/60/60-vis_duration/24/60/60,13),'.',num2str(milliseconds),'Z');
    pointintimee=strcat(datestr(initialtime+t(i)/24/60/60+vis_duration/24/60/60,29),'T',datestr(initialtime+t(i)/24/60/60+vis_duration/24/60/60,13),'.',num2str(milliseconds),'Z');
    %fprintf(id,'\n		    <gx:TimeStamp><when> %s </when></gx:TimeStamp>',pointintime');
    fprintf(id,'\n  <gx:TimeSpan><begin>%s</begin><end>%s</end></gx:TimeSpan>',pointintimeb,pointintimee);
    %% set viewpoint and heading to according to flight direction
    if i==1  %% first point
      fprintf(id,'\n  <longitude>%f</longitude><latitude>%f</latitude><altitude>%f</altitude>',Long(1,i)+longviewoffset*(90-abs(Lat(1,i) ))/90,Lat(1,i)-latviewoffset,altitudeview);
      fprintf(id,'\n  <heading>%f</heading><tilt>%f</tilt><roll>0</roll>',headingviewoffset*(90-abs(Lat(1,i) ))/90,tiltview);
    elseif Lat(1,i)==max([Lat(1,i-1) Lat(1,i) Lat(1,i+1)]) %% on northpole
      if abs( abs(Long(j,i)) - abs(Long(j,i-1)) )<abs( abs(Long(j,i)) - abs(Long(j,i+1)) ) %% before northpole, i.e. northern direction
        fprintf('\nbnp%d',i)
        fprintf(id,'\n  <longitude>%f</longitude><latitude>%f</latitude><altitude>%f</altitude>',Long(1,i)+longviewoffset*(90-abs(Lat(1,i) ))/90,Lat(1,i)-latviewoffset,altitudeview);
        fprintf(id,'\n  <heading>%f</heading><tilt>%f</tilt><roll>0</roll>',headingviewoffset*(90-abs(Lat(1,i) ))/90,tiltview);            
      elseif abs( abs(Long(j,i)) - abs(Long(j,i-1)) )>abs( abs(Long(j,i)) - abs(Long(j,i+1)) ) %% after northpole, i.e. southern direction
        fprintf('\nanp%d',i)
        fprintf(id,'\n  <longitude>%f</longitude><latitude>%f</latitude><altitude>%f</altitude>',Long(1,i)-longviewoffset*(90-abs(Lat(1,i) ))/90,Lat(1,i)+latviewoffset,altitudeview);
        fprintf(id,'\n  <heading>%f</heading><tilt>%f</tilt><roll>0</roll>',180+headingviewoffset*(90-abs(Lat(1,i) ))/90,tiltview);        
      end    
    elseif Lat(1,i)==min([Lat(1,i-1) Lat(1,i) Lat(1,i+1)]) %% on southpole
       if abs(abs(Long(j,i))-abs(Long(j,i-1)))<abs(abs(Long(j,i))-abs(Long(j,i+1))) %% before southpole, i.e. southern direction
         fprintf('\nbsp%d',i)
         fprintf(id,'\n  <longitude>%f</longitude><latitude>%f</latitude><altitude>%f</altitude>',Long(1,i)-longviewoffset*(90-abs(Lat(1,i) ))/90,Lat(1,i)+latviewoffset,altitudeview);
         fprintf(id,'\n  <heading>%f</heading><tilt>%f</tilt><roll>0</roll>',180+headingviewoffset*(90-abs(Lat(1,i) ))/90,tiltview);    
       elseif abs(abs(Long(j,i))-abs(Long(j,i-1)))>abs(abs(Long(j,i))-abs(Long(j,i+1))) %% after southpole, i.e. northern direction
         fprintf('\nasp%d',i)
         fprintf(id,'\n  <longitude>%f</longitude><latitude>%f</latitude><altitude>%f</altitude>',Long(1,i)+longviewoffset*(90-abs(Lat(1,i) ))/90,Lat(1,i)-latviewoffset,altitudeview);
         fprintf(id,'\n  <heading>%f</heading><tilt>%f</tilt><roll>0</roll>',headingviewoffset*(90-abs(Lat(1,i) ))/90,tiltview);                     
       end         
     elseif Lat(1,i+1)-Lat(1,i)>=0 %% northern direction
       %printf('\nnd%d',i)      
       fprintf(id,'\n  <longitude>%f</longitude><latitude>%f</latitude><altitude>%f</altitude>',Long(1,i)+longviewoffset*(90-abs(Lat(1,i) ))/90,Lat(1,i)-latviewoffset,altitudeview);
       fprintf(id,'\n  <heading>%f</heading><tilt>%f</tilt><roll>0</roll>',headingviewoffset*(90-abs(Lat(1,i) ))/90,tiltview);
     elseif Lat(1,i+1)-Lat(1,i)<0  %% southern direction
       %printf('\nsd%d',i)
       fprintf(id,'\n  <longitude>%f</longitude><latitude>%f</latitude><altitude>%f</altitude>',Long(1,i)-longviewoffset*(90-abs(Lat(1,i) ))/90,Lat(1,i)+latviewoffset,altitudeview);
       fprintf(id,'\n  <heading>%f</heading><tilt>%f</tilt><roll>0</roll>',180+headingviewoffset*(90-abs(Lat(1,i) ))/90,tiltview);
     else
       fprintf('error')
     end
     fprintf(id,'\n</Camera></gx:FlyTo>');
    end
  end
  fprintf(id,'\n</gx:Playlist></gx:Tour>');
    
  
  if USyn
    %% US path
    fprintf(id,'\n<Placemark><name>US</name><styleUrl>#stylesel_0</styleUrl><gx:Track><altitudeMode>absolute</altitudeMode>');     
    fprintf(id,'\n   <Model id="geom_0"><altitudeMode>absolute</altitudeMode>');
    fprintf(id,'\n      <Orientation><heading>0.0</heading><tilt>90</tilt><roll>0</roll></Orientation>');
    fprintf(id,'\n      <Scale><x>10000</x><y>10000</y><z>10000</z></Scale>');
    fprintf(id,'\n      <Link id="link_0"><href>figures/simpleUS.dae</href></Link>');
    fprintf(id,'\n    </Model>');
    for i=1:size(UStime,2)
      fprintf(id,'\n<gx:coord> %f %f %f</gx:coord>',USLong(i),USLat(i),(USrs(i)-6371)*1000); 
    end 
    for i=1:size(UStime,2)
      pointintime=strcat(datestr(initialtime+UStime(i)/24/60/60,29),'T',datestr(initialtime+UStime(i)/24/60/60,13),'Z');
      fprintf(id,'\n<when> %s </when>',pointintime);
    end
    %for i=1:size(UStime,2)
      % fprintf(id,'\n<gx:angles>%f %f %f</gx:angles>',angles(j-1,1,i),angles(j-1,2,i),angles(j-1,3,i));
    %end 
    fprintf(id,'\n  </gx:Track></Placemark>');
  end
  
   %% satellites' time, angles and coordinates
  for j=2:ns+1
    fprintf(id,'\n<Placemark><name>sat%d</name><styleUrl>#stylesel_0</styleUrl><gx:Track><altitudeMode>absolute</altitudeMode>',j-1);     
    fprintf(id,'\n   <Model id="geom_0"><altitudeMode>absolute</altitudeMode>');
    fprintf(id,'\n      <Orientation><heading>90.0</heading><tilt>0</tilt><roll>0</roll></Orientation>');
    if j==ns+1 && masterfilename~=""
      fprintf(id,'\n      <Link id="link_0"><href>%s</href></Link>',masterfilename);
      fprintf(id,'\n      <Scale><x>%f</x><y>%f</y><z>%f</z></Scale>',3*modelscalex,3*modelscaley,3*modelscalez);
    else
      fprintf(id,'\n      <Link id="link_0"><href>%s</href></Link>',modelfilename);
      fprintf(id,'\n      <Scale><x>%f</x><y>%f</y><z>%f</z></Scale>',modelscalex,modelscaley,modelscalez);
    end
    fprintf(id,'\n   </Model>');

    for i=1:size(t,2)
      fprintf(id,'\n  <gx:coord> %f %f %f</gx:coord>',Long(j,i),Lat(j,i),(rs(j,i)-6371)*1000); 
    end 
    for i=1:size(t,2)
      milliseconds=round(1000*(initialtime*24*60*60+t(i)-floor(initialtime*24*60*60+t(i))));
      pointintime=strcat(datestr(initialtime,29),'T',datestr(initialtime+t(i)/24/60/60,13),'.',num2str(milliseconds),'Z');
      fprintf(id,'\n  <when> %s </when>',pointintime);
    end
    for i=1:size(t,2)
      %fprintf(id,'\n  <gx:angles>%f %f %f</gx:angles>',angles(2,j-1,i),angles(1,j-1,i),angles(3,j-1,i));%% yaw,pitch, roll 
      fprintf(id,'\n  <gx:angles>%f %f %f</gx:angles>',zaxvgrid(j-1,i),yaxvgrid(j-1,i),xaxvgrid(j-1,i));%% yaw,pitch, roll 
    end 
    fprintf(id,'\n  </gx:Track></Placemark>');
   end
   k=1;
   if footprintyn
     while k<size(footprintsize,2)
       fprintf(id,'\n<Placemark><name>centerpoint</name><styleUrl>#stylesel_0</styleUrl>>');     
       fprintf(id,'\n   <Model id="geom_1"><altitudeMode>relativeToGround</altitudeMode>');
       fprintf(id,'\n       <Orientation><heading>90.0</heading><tilt>0</tilt><roll>0</roll></Orientation>');        
       fprintf(id,'\n       <Scale><x>%f</x><y>%f</y><z>%f</z></Scale>',footprintsize(k),footprintsize(k),footprintsize(k)); 
       fprintf(id,'\n       <Location>');
       fprintf(id,'\n        <longitude>%f</longitude> <!-- kml:angle180 -->',Long(1,k)); %% below virtual satellite
       fprintf(id,'\n        <latitude>%f</latitude>   <!-- kml:angle90 -->',Lat(1,k));%% below virtual satellite
       fprintf(id,'\n       <altitude>%f</altitude>  <!-- double -->',100);
       fprintf(id,'\n       </Location>');
       fprintf(id,'\n       <Link id="link_1"><href>figures%storus.dae</href></Link>',filesep);
       fprintf(id,'\n    </Model>');
       milliseconds=round(1000*(initialtime*24*60*60+t(i)-floor(initialtime*24*60*60+t(i))));
       pointintime=strcat(datestr(initialtime,29),'T',datestr(initialtime+t(k)/24/60/60,13),'.',num2str(milliseconds),'Z');
       fprintf(id,'\n     <TimeStamp><when> %s </when></TimeStamp>',pointintime);
       fprintf(id,'\n</Placemark>');  
       k=k+1;
     end
   end
   fprintf(id,'\n  </Folder>');
   fprintf(id,'\n </kml>');
   fclose(id);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [E] = anom_ecc(M,e)
  % function [E] = anom_ecc(M,e) 
  % Risoluzione numerica dell'equazione: E-e*sin(E)=M
  % E = anomalia eccentrica [rad]
  % e = eccentricità
  % M = anomalia media [rad]
  % Si devono dare in input alla funzione due valori scalari,
  % rispettivamente M in rad ed e.
  % Il programma restituisce E [rad] con un errore di 1e-10
  % N.B. Per migliorare l'accuratezza accedere all'editor e modificare il
  % valore della variabile err, che rappresenta l'errore commesso.
  
  format long
  %x = 0;
  %sx = 1;
  %dymax = -1;
  %trovato = true;
  %while (trovato)
  %if (sx<0.2)
  % sx = 0.1 - (x/1000);
  % else
  % sx  = M-x;
  % dx  = M+x;
  % dy  = abs(cos(dx));
  %  dy2 = abs(cos(sx));
  %  end
  %  if (dymax<dy || dymax<dy2)
  %  if (dy<dy2)
  %  dymax = dy2;
  %  else
  %  dymax = dy;
  %  dy = dymax;
  %  end
  %  end 
  %  f0 = sx-e.*sin(sx)-M;
  %  f1 = dx-e.*sin(dx)-M;
  %  trovato = ((f0.*f1)>0);
  %  x = x + 0.1;
  %  end
  E = M;
  k = 1;
  err = 1e-10;
  % stabilito intervallo di ricerca (sx,dx) e max valore derivata dymax;
  while (k>err)
    y = e*sin(E)+M;
    k = abs(abs(E)-abs(y));
    E = y;
  end
  % trovato E con un errore inferiore a 0.1*10^(-4);
  %fprintf(' La soluzione E è stata trovata nell''intervallo [%2.5f,%2.5f]',sx,dx);
  %fprintf(' \n errore inferiore a %1.2e: [rad] E = %3.5f',err,E);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%







































%{
function [dxdt,anglestemp,u]=hcwequation(t,x,IR,P,A,B,xdi,currenttime,timespan,rho,v)
%% HCW equation
  persistent ang;
  persistent timearray;

  satmass=2; %% kg
  S=0.1^2; %% m2
  k=1/satmass*rho*v^2*S;
  umax=-k*1.2/satmass;
  uyzmax=k*0.24/satmass;
  xdi2x = interp1(currenttime+timespan,squeeze(xdi(1,1,:)),currenttime+t);% Interpolate the data set (ft,f) at time t
  xdi2y = interp1(currenttime+timespan,squeeze(xdi(2,1,:)),currenttime+t); % Interpolate the data set (ft,f) at time t
  xdi2z = interp1(currenttime+timespan,squeeze(xdi(3,1,:)),currenttime+t); % Interpolate the data set (ft,f) at time t
  xdi2=[xdi2x xdi2y xdi2z zeros(size(xdi2x,1),1) zeros(size(xdi2x,1),1) zeros(size(xdi2x,1),1)]';
  %% error vector
  e=x-xdi2;
  %% control vector
  u1=-IR*B'*P*e;
  
  u=u1;%-[umax/2 0 0]'; %% to set u to a default value and size u correctly
  %{
  for i=1:size(u,2)
    if u(1,i)>=1/2*umax; %% going forward with drag
      u(1,i)=1/2*umax;
      u(2,i)=0;
      u(3,i)=1/2*umax*100;
    elseif u(1,i)<=-1/2*umax %% going backward 
      u(1,i)=-1/2*umax;
      u(2,i)=0;
      u(3,i)=0;
    %elseif sqrt(u(2,i)^2+u(3,i)^2)>uyzmax
      %  u(1,i)=-0.8;
      %  u(2,i)=u1(2,i)/uyzmax;
      %  u(3,i)=u1(3,i)/uyzmax;
    else 
      print('error')
    end
  end
%}  
%anglestempX(1,:)=asind(1/1.2*u(1,:)/k)+asind(1/1.2*umax/k);
  %anglestempX(2,:)=0;
  %anglestempX(3,:)=0;
  for i=1:size(u,2)
      if u(1,i)<0
        u1temp=-u(1,i);
      else
          u1temp=u(1,i);
      end
      anglestemptemp(1,i) = asind( u(3,i)./sqrt( u(1,i)^2 + u(3,i)^2));%pitch
      anglestemptemp(2,i) = asind( u(2,i)./sqrt( u(1,i)^2 + u(2,i)^2));%yaw
      anglestemptemp(3,i) = asind( u(3,i)./sqrt( u(2,i)^2 + u(3,i)^2));%roll
      %fprintf('\n u1temp %f umax %f',u1temp,umax);
  end
  %% getting angles
  if size(ang,1)>0 && size(x,2)==1 %% TBC: enter only when solving ODE but not first time
    ang=[ang  anglestemptemp];
  elseif size(ang,1)==0 && size(x,2)==1%% TBC: enter only when solving ODE,first time
    ang=anglestemptemp;
  elseif size(ang,1)>0 && size(x,2)>1%% TBC: enter when getting all angles  
    ang=anglestemptemp;
  else
    fprintf('\n error with getting the angles')
  end
  anglestemp=ang;
  dxdt=A*x+B*u;
end
%}

%{

%% use 1 Matlab ODE, 2 home made, or 3 home made non vector based
UMOO=2;

%% parameters for ODE45
opts = odeset('RelTol',1e-2,'AbsTol',1e-4);


%%%%%%%%%%%%%%%%%%%%%%%%%

  if UMOO==1
    for i=1:ns
        %% solve ODE      
        [t,x]=ode23(@(t,x) hcwequation(t,x,IR,P,A,B,xd(:,i,:),currenttime,timetemp),timetemp,ssttemp(:,i,size(ssttemp,3)),opts,rho,v);
        ssttemp(:,i,:)=x';  %% columns: statevector, rows: (x,y,z,u,v,w), depth: timeevolution   
        %% get data out of ODE
        [a1,anglestemp(:,i,:),u]=hcwequation(t,x',IR,P,A,B,xd(:,i,:),currenttime,timetemp,rho,v);
        clear hcwequation
     end
  elseif UMOO==2 %% use home made vector based solver: Euler backward
  elseif UMOO==3 %% use home made loop based solver
    ;
  else
    fprintf('error in choosing ODE solver');
  end

%}