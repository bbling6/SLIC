close all;
clear all;

Ki = 15; %nbr superpixel en y
Kj = 15; %nbr superpixel en x

pourcentageFusion=0.2;

ratio=0.6;%Compression de l'image

n = 9; %Taille voisinage (impaire)
m = 5;
seuil = 145; %Binarisation

imga = imread('images/viff.000.ppm');
img = imresize(imga, ratio);

%Conversion Lab
C = makecform('srgb2lab');
lab = applycform(img,C);

L(:,:) = double(lab(:,:,1));
A(:,:) = double(lab(:,:,2));
B(:,:) = double(lab(:,:,3));

K=Ki*Kj;
% R(:,:) = img(:,:,1);
% V(:,:) = img(:,:,2);
% B(:,:) = img(:,:,3);

%affichage_image(img,'SLIC',1);
figure;
imagesc(img);
figure;
imagesc(lab);

[nlignes,ncolonnes,ncanaux] = size(img);
N = nlignes*ncolonnes;
tailleMoyenne = N/K;

%Initialisation
S=sqrt(N/(Ki*Kj));
Si = nlignes/Ki;
Sj = ncolonnes/Kj;
centres = zeros(Ki*Kj,5);
[I,J] = meshgrid(1:ncolonnes,1:nlignes);
l = 1;
for i=1:Ki
    y = min((2*i -1)*round(nlignes/(2*Ki)),nlignes);
    for j=1:Kj
        x = min((2*j -1)*round(ncolonnes/(2*Kj)),ncolonnes);
        %[x y R(y,x) V(y,x) B(y,x)]
        %centres(l,:) = [x y R(y,x) V(y,x) B(y,x)];
        centres(l,5) = x;centres(l,4)=y;centres(l,1) = L(y,x);centres(l,2)= A(y,x);centres(l,3)=B(y,x);
        l=l+1;
    end;
end;

hold on;
for p=1:Ki*Kj
    plot(centres(p,5),centres(p,4),'+','MarkerSize',10,'MarkerEdgeColor','b');
end;
pause;

%Decalage centres
[Fx,Fy] = gradient(L(:,:));
voisinageFx=zeros(n,n);
voisinageFy=zeros(n,n);

for i=1:K
    xcentre = centres(i,5);
    ycentre = centres(i,4);
    
    
%     minx = max(floor(xcentre - (n-1)/2),1);
%     maxx = min(floor(xcentre + (n-1)/2),ncolonnes);
%     miny = max(floor(ycentre - (n-1)/2),1);
%     maxy = min(floor(ycentre + (n-1)/2),nlignes);
    
    minx = floor(xcentre - (n-1)/2);
    maxx = floor(xcentre + (n-1)/2);
    miny = floor(ycentre - (n-1)/2);
    maxy = floor(ycentre + (n-1)/2);
    if(minx>1 & maxx<ncolonnes & miny>1 & maxy<nlignes)
    
    voisinageFx(1:n,1:n) = Fx(miny:maxy,minx:maxx);
    voisinageFy(1:n,1:n) = Fy(miny:maxy,minx:maxx);
    normvoisi(1:n,1:n) = voisinageFx.^2 + voisinageFy.^2;
    
    [M,Indmin] = min(normvoisi(:));
    [I_row, I_col] = ind2sub(size(normvoisi),Indmin);
    
    di = I_row - (n-1)/2;
    dj = I_col - (n-1)/2;
    xcentre = xcentre+dj;
    ycentre = ycentre+di;
    centres(i,:) = [L(ycentre,xcentre) A(ycentre,xcentre) B(ycentre,xcentre) ycentre xcentre];
    end;
end;

figure;
imagesc(img);

hold on;
for p=1:K
    plot(centres(p,5),centres(p,4),'+','MarkerSize',10,'MarkerEdgeColor','b');
end;
pause;


X = double([ L(:) A(:) B(:) I(:) J(:)]);


[idx,centres] = kmeans2(X,Ki*Kj,m,S,'start',centres,'distance','sqEuclidean');

%affichage_resultat(X,idx,K,ncanaux,'Segmentation SLIC',1);
figure;
imgidx = reshape(idx,nlignes,ncolonnes);
imagesc(imgidx);
pause;


%FUSION DES REGIONS

imgClasse(:,:) = reshape(idx,nlignes,ncolonnes);
imgClasseNum = zeros(nlignes,ncolonnes);
dernierId = 0;

index = [];

for classeCourante=1:K
    H=zeros(nlignes,ncolonnes);
    H(imgClasse==classeCourante)=1;
    [conn,num] = bwlabel(H,8);
    conn(conn~=0) = conn(conn~=0) + dernierId;
    imgClasseNum = imgClasseNum + conn;
    index(dernierId+1:dernierId+num) = classeCourante;
    dernierId = dernierId+num;
end;

conn=imgClasseNum;
num = dernierId;

seuilFusion = floor(pourcentageFusion*tailleMoyenne);
termine = false;
deci=[-1 -1 -1 0 0 +1 +1 +1];
decj=[-1 0 1 -1 +1 -1 0 +1];

while (~termine)
    termine = true;
    for composanteCourante=1:num
        composanteCourante/num
        taille = length(find(conn==composanteCourante));
        if( taille<=seuilFusion & taille>0)
            %Recherche de la zone voisine la plus grande
            
            %construction vecteur adjacence
            adja = zeros(num,1);
            [r,c,v] = find(conn==composanteCourante);
            for u=1:length(r)
                indi=r(u);
                indj=c(u);
                for g=1:8
                    iadja=indi+deci(g);jadja=indj+decj(g);
                    if(iadja<nlignes & iadja>0 & jadja<ncolonnes & jadja>0)
                        connij = conn(iadja,jadja);
                        if(connij~=composanteCourante)
                            adja(connij) = length(find(conn==connij));
                        end;
                    end;
                end;
            end;
            
            [val,indmax] = max(adja);
            %fusion
            conn(conn==composanteCourante) = indmax;
            termine = false;
        end;
    end;
end;

%Réindexage
for i=1:nlignes
    for j=1:ncolonnes
        conn(i,j) = index(conn(i,j));
    end;
end;

figure;
%affichage_resultat(X,conn(:),K,ncanaux,'Segmentation SLIC',1);
imagesc(conn);


%Segmentation Binaire

centresInterieur = find(centres(:,1)>seuil);
binarisation = zeros(nlignes,ncolonnes);
for i=1:length(centresInterieur)
    H = conn == centresInterieur(i);
    binarisation = binarisation + H;
end;

figure;
imagesc(binarisation);

% C2 = makecform('lab2srgb');
% centresrgb = applycform(centres(:,1:3),C2);
% 
% centresInterieur = find(centresrgb(:,1)>seuil);
% binarisation = zeros(nlignes,ncolonnes);
% for i=1:length(centresInterieur)
%     H = conn == centresInterieur(i);
%     binarisation = binarisation + H;
% end;
% 
% figure;
% imagesc(binarisation);



