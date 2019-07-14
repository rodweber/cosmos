%plotaerodynamics2
close all;clc;clear all;

%totalforcevector=zeros(3,size(gamma,2),size(beta,2),size(alpha,2));

solarconstant=1;
sunlight=solarconstant*[0 1 0]';
rho=2; v=1;
wind=rho/2*v^2*[-1 0 0]';
noxpanels=0;noypanels=1;nozpanels=0;
controlvector=[1 0 0]';

alpha=0:3:360; %% yaw
beta=0:3:360; %% pitch 
gamma=0:3:360; %%roll

totalforcevector = totalforcevectorfunction(wind,sunlight,noxpanels,noypanels,nozpanels,alpha,beta,gamma);

[alpha1,beta1,gamma1]=findBestAerodynamicAngles(totalforcevector,controlvector,alpha,beta,gamma);

alpha1
beta1
gamma1

function totalforcevector=totalforcevectorfunction(wind,sunlight,noxpanels,noypanels,nozpanels,alpha,beta,gamma)
      
    %Rx90=[0 1 0 ;-1 0  0 ; 0 0 1];
    %Rz90=[1 0 0 ; 0 0 -1 ; 0 1 0];
    %Iy = [0 1 0]';
    %Ix=Rz90*Iy;
    %Iz=Rx90*Iy;

    Rx90=[0 1 0 ;-1 0  0 ; 0 0 1];
    %Ry =[cosd(beta(j))  0 sind(beta(j))  ; 0 1 0                          ; -sind(beta(j)) 0 cosd(beta(j))]; %% pitch
    Ry90=[0 0 1 ; 0 1 0 ; -1 0 0];
    Rz90=[1 0 0 ; 0 0 -1 ; 0 1 0];
    Iz = [0 0 1]';
    Ix=Ry90*Iz;
    Iy=Rx90*Iz;
    %% yplate
    p1  = [1,0,1];p2 = [-1,0,1];p3 = [-1,0,-1];p4 = [1,0,-1];
    p12 = [0.33,0,0.33];p22 = [-0.33,0,0.33];p32 = [-0.33,0,-0.33];p42 = [0.33,0,-0.33];
    p13 = [0.66,0,0.66];p23 = [-0.66,0,0.66];p33 = [-0.66,0,-0.66];p43 = [0.66,0,-0.66];
    %% zplate
    pz1  = [1,1,0];pz2 = [1,-1,0];pz3 = [-1,-1,0];pz4 = [-1,1,0];
    pz12 = [0.33,0.33,0];pz22 = [0.33,-0.33,0];pz32 = [-0.33,-0.33,0];pz42 = [-0.33,0.33,0];
    pz13 = [0.66,0.66,0];pz23 = [0.66,-0.66,0];pz33 = [-0.66,-0.66,0];pz43 = [-0.66,0.66,0];
    drag=zeros(size(alpha,2),1);
    lift=zeros(size(alpha,2),1);
    totalforcevector=zeros(3,size(gamma,2),size(beta,2),size(alpha,2));
    
    thetaaero=zeros(size(gamma,2),size(beta,2),size(alpha,2));
    phiaero=zeros(size(gamma,2),size(beta,2),size(alpha,2));
    thetasun=zeros(size(gamma,2),size(beta,2),size(alpha,2));
    phisun=zeros(size(gamma,2),size(beta,2),size(alpha,2));
    drag=zeros(size(gamma,2),size(beta,2),size(alpha,2));
    lift=zeros(size(gamma,2),size(beta,2),size(alpha,2));

    for k=1:size(gamma,2) %% yaw
      %for j=1:size(beta,2) %% pitch
        %for i=1:size(alpha,2) %% roll
            %k=1; %% yaw
            j=31; %% pitch
            i=1;%% roll
                %% rotation matrizes
                Rz2=[cosd(alpha(k)) -sind(alpha(k)) 0; sind(alpha(k)) cosd(alpha(k)) 0; 0 0 1]; %% yaw
                Ry =[cosd(beta(j))  0 sind(beta(j))  ; 0 1 0                          ; -sind(beta(j)) 0 cosd(beta(j))]; %% pitch
                Rz =[cosd(gamma(i)) -sind(gamma(i)) 0; sind(gamma(i)) cosd(gamma(i)) 0; 0 0 1]; %%roll

                pg = [(Rz2*Ry*Rz*pz1')' ; (Rz2*Ry*Rz*pz2')' ; (Rz2*Ry*Rz*pz3')' ; (Rz2*Ry*Rz*pz4')' ; (Rz2*Ry*Rz*pz1')'];
                pg2 = [(Rz2*Ry*Rz*pz12')' ; (Rz2*Ry*Rz*pz22')' ; (Rz2*Ry*Rz*pz32')' ; (Rz2*Ry*Rz*pz42')' ; (Rz2*Ry*Rz*pz12')'];
                pg3 = [(Rz2*Ry*Rz*pz13')' ; (Rz2*Ry*Rz*pz23')' ; (Rz2*Ry*Rz*pz33')' ; (Rz2*Ry*Rz*pz43')' ; (Rz2*Ry*Rz*pz13')'];
                Ig=Rz2*Ry*Rz*Iz;
                otherside=1;
                Ig2=Ig;
                [thetaaero(i,j,k),phiaero(i,j,k,otherside),otherside,Ig2]=thetaphi(wind, Ig);
                [drag(i,j,k),lift(i,j,k)]=aerodraglift(thetaaero(i,j,k),phiaero(i,j,k));
                ax=cross(wind,Ig2)                
                liftvector = rodrigues_rot(wind,ax,90/180*pi)
                aeroforcevector=-wind/sqrt(wind(1)^2+wind(2)^2+wind(3)^2)*drag(i,j,k);
                aeroforcevector=-liftvector/sqrt(wind(1)^2+wind(2)^2+wind(3)^2)*lift(i,j,k)+aeroforcevector;
                
                [thetasun(i,j,k),phisun(i,j,k),otherside,Ig2]=thetaphi(sunlight,Ig);
                [dragsun(i,j,k),liftsun(i,j,k)]=sundraglift(thetasun(i,j,k),phisun(i,j,k));
                ax=cross(sunlight,Ig2)                
                liftvector = rodrigues_rot(sunlight,ax,90/180*pi)
                sunforcevector=-sunlight/sqrt(sunlight(1)^2+sunlight(2)^2+sunlight(3)^2)*dragsun(i,j,k);
                sunforcevector=-liftvector/sqrt(sunlight(1)^2+sunlight(2)^2+sunlight(3)^2)*liftsun(i,j,k)+sunforcevector;

%                totalforcevector(:,i,j,k)=aeroforcevector+sunforcevector;
            %% draw
            vectarrow(Ig);hold on;text(Ig(1),Ig(2),Ig(3),"normal",'HorizontalAlignment','left','FontSize',6);
            line(pg(:,1), pg(:,2), pg(:,3));line(pg2(:,1), pg2(:,2), pg2(:,3));line(pg3(:,1), pg3(:,2), pg3(:,3));
            vectarrow(sunlight);hold on;text(sunlight(1),sunlight(2),sunlight(3),"sunlight",'HorizontalAlignment','left','FontSize',6);
            vectarrow(wind);hold on;text(wind(1),wind(2),wind(3),"wind",'HorizontalAlignment','left','FontSize',6);
            %vectarrow(aeroforcevector);hold on;text(aeroforcevector(1),aeroforcevector(2),aeroforcevector(3),"aeroforce",'HorizontalAlignment','left','FontSize',6);
            vectarrow(sunforcevector);hold on;text(sunforcevector(1),sunforcevector(2),sunforcevector(3),"sunforce",'HorizontalAlignment','left','FontSize',6);            
            %vectarrow(totalforcevector(:,i,j,k))
            axis equal;hold off;axis([-1 1 -1 1 -1 1])
            pause(1)
        end
      %end
    %end

    thetaaero=squeeze(thetaaero(i,:,k));
    phiaero=squeeze(phiaero(i,:,k));

    drag=squeeze(drag(:,j,k));
    lift=squeeze(lift(:,j,k));

    figure
        subplot(2,1,1)
        plot(alpha,thetaaero,alpha,phiaero);
        legend('thetaaero','phiaero');grid on;
        subplot(2,1,2)
        plot(alpha,drag,alpha,lift);
        legend('drag','lift');grid on;

end
function [theta,phi,otherside,Ig2]=thetaphi(refvec, vec)
  theta = atan2d(norm(cross(refvec,vec)), dot(refvec,vec));
  if theta>90
      theta=180-theta;
      otherside=-1;
      Ig2=-vec;
  else
      otherside=1;
      Ig2=vec;
  end
  phi=atand( (refvec(3)-vec(3)) / (refvec(2)-vec(2)) );
end

function [drag lift]=aerodraglift(theta,phi)
  drag=-abs(sind(theta-90)); %%simplified formula
  lift=-abs(sind(2*(theta-90)));%*sign(theta); %% simplified formula     
end

function [drag lift]=sundraglift(theta,phi)
  drag=-abs(sind(theta-90)); %%simplified formula
  lift=-abs(sind(2*(theta-90)));%*sign(theta); %% simplified formula     
end


function [alpha1,beta1,gamma1]=findBestAerodynamicAngles(totalforcevector,controlvector,alpha,beta,gamma) 
    theta=zeros(size(gamma,2),size(beta,2),size(alpha,2));
    for k=1:size(gamma,2) %% yaw
      for j=1:size(beta,2) %% pitch
        for i=1:size(alpha,2) %% roll
            [theta(i,j,k),phi]=thetaphi(totalforcevector(:,i,j,k),controlvector);
        end
      end
    end
    [theta(i,j,k),phi]=thetaphi(totalforcevector(:,i,j,k),controlvector);
    %! find indizes of smallest theta    
    i=1;j=1;k=1;
    alpha1=alpha(i,j,k);
    beta1=beta(i,j,k);
    gamma1=gamma(i,j,k);
end



% rodrigues_rot - Rotates array of 3D vectors by an angle theta about vector k.
% Direction is determined by the right-hand (screw) rule.
%
% Syntax:  v_rot = rodrigues(v,k,theta)
%
% Inputs:
%    v - Array of three dimensional vectors to rotate. Array can be 
%           composed of N rows of 3D row vectors or N columns of 3D column
%           vectors. If v is 3x3 array, it is assumed that it is 3 rows of
%           3 3D row vectors.
%    k - Rotation axis (does not need to be unit vector)
%    theta - Rotation angle in radians; positive according to right-hand
%           (screw) rule
%
%   Note: k and individual 3D vectors in v array must be same orientation.
%           
%
% Outputs:
%    v_rot - Array of rotated vectors.
%
% Other m-files required: dot.m (built-in MATLAB)
% Subfunctions: none
% MAT-files required: none
%
% Author: Ismail Hameduddin
%           Mechanical Engineering, Purdue University
% email: ihameduddin@gmail.com
% Website: http://www.ismailh.com
% January 2011; Last revision: 2-January-2012
%------------- BEGIN CODE --------------
function v_rot = rodrigues_rot(v,k,theta)
    [m,n] = size(v);
    if (m ~= 3 && n ~= 3)
        error('input vector is/are not three dimensional'), end
    if (size(v) ~= size(k)) 
        error('rotation vector v and axis k have different dimensions'),end
    
    k = k/sqrt(k(1)^2 + k(2)^2 + k(3)^2); % normalize rotation axis
    No = numel(v)/3; % number of vectors in array
    v_rot = v; % initialize rotated vector array
    if ( n == 3 )
        crosskv = v(1,:); % initialize cross product k and v with right dim.
        for i = 1:No
            crosskv(1) = k(2)*v(i,3) - k(3)*v(i,2);
            crosskv(2) = k(3)*v(i,1) - k(1)*v(i,3); 
            crosskv(3) = k(1)*v(i,2) - k(2)*v(i,1);
            v_rot(i,:) = cos(theta)*v(i,:) + (crosskv)*sin(theta)...
                            + k*(dot(k,v(i,:)))*(1 - cos(theta));
        end
    else % if m == 3 && n ~= 3
        crosskv = v(:,1); % initialize cross product k and v with right dim.
        for i = 1:No
            crosskv(1) = k(2)*v(3,i) - k(3)*v(2,i);
            crosskv(2) = k(3)*v(1,i) - k(1)*v(3,i); 
            crosskv(3) = k(1)*v(2,i) - k(2)*v(1,i);
            v_rot(:,i) = cos(theta)*v(:,i) + (crosskv)*sin(theta)...
                            + k*(dot(k,v(:,i)))*(1 - cos(theta));
        end
    end
end
%------------- END OF CODE --------------