function o=iss_register(o)
% o=iss_register(o)
%
% register images based on tile files
% creates arrays o.RefPos(y, x): origin of tile (y,x) in pixels on
% reference round relative to global coordinate frame
% 
% o.RelativePos(r, 1:2, t1, t2): origin of tile t2 on 
% reference round minus origin of tile t1 round r. In other words,
% Im2(x;rr) = Im1(x + RelativePos; r). Nan if not defined
% t1 and t2 are linear indices for the tile (y,x)
%
% also makes a global DAPI image 
% 
% Kenneth D. Harris, 29/3/17
% GPL 3.0 https://www.gnu.org/licenses/gpl-3.0.en.html
 
%% first let's load in all the reference tiles to save time later
rr = o.ReferenceRound;
EmptyTiles = strcmp('', squeeze(o.TileFiles(rr,:,:)));
Tiles = find(~EmptyTiles)';
Tiles = Tiles(:)';

[nY, nX] = size(EmptyTiles);
nTiles = nY*nX;
RefTiles = zeros(o.TileSz, o.TileSz, nY, nX, 'uint16');

for t=Tiles(:)'
    [y,x] = ind2sub([nY nX], t);
    if mod(t,10)==0; fprintf('Loading tile %d\n', t); end
    RefTiles(:,:,t) = imread(o.TileFiles{rr,y,x}, o.AnchorChannel);
    oNoGraphics = o; oNoGraphics.Graphics=0;
    RefSpots{t} = iss_detect_spots(RefTiles(:,:,t), oNoGraphics);
end

%% first we stitch the tiles on the reference round


% zero/one array saying if both tiles are there to make a pair
VerticalPairs = ~EmptyTiles(1:end-1,:) & ~EmptyTiles(2:end,:);
HorizontalPairs = ~EmptyTiles(:,1:end-1) & ~EmptyTiles(:,2:end);
nVerticalPairs = sum(VerticalPairs(:));
nHorizontalPairs = sum(HorizontalPairs(:));

% to store results of pairwise image registrations
% stores global coordinate of lower or right tile relative to upper or left
vShifts = nan(nVerticalPairs,2);
hShifts = nan(nHorizontalPairs,2);
ccv = zeros(nVerticalPairs,1);
cch = zeros(nHorizontalPairs,1);

for i=1:numel(VerticalPairs)
    if VerticalPairs(i)==0; continue; end;
    [y,x] = ind2sub(size(VerticalPairs), i);
    [vShifts(i,:), ccv(i)] = ImRegFft(RefTiles(:,:,y,x), RefTiles(:,:,y+1,x), 's', o.CorrThresh, o.MinSize);
    fprintf('%d, %d, down: shift %d %d, cc %f\n', y, x, vShifts(i,:), ccv(i));
end

for i=1:numel(HorizontalPairs)
    if HorizontalPairs(i)==0; continue; end;
    [y,x] = ind2sub(size(HorizontalPairs), i);
    [hShifts(i,:), cch(i)] = ImRegFft(RefTiles(:,:,y,x), RefTiles(:,:,y,x+1), 'e', o.CorrThresh, o.MinSize);
    fprintf('%d, %d, right: shift %d %d, cc %f\n', y, x, hShifts(i,:), cch(i));
end

% now we need to solve a set of linear equations for each shift, that makes
% each tile position the mean of what is suggested by all pairs it appears
% in. This will be of the form M*x = c, where x and c are both of length 
% nTiles=nY*nX. The t'th row is the equation for tile t. 
% c has columns for y and x coordinates

M = zeros(nTiles, nTiles);
c = zeros(nTiles, 2);
for i=find(VerticalPairs)'
    if isnan(vShifts(i,1)); continue; end;
    [y1,x1] = ind2sub(size(VerticalPairs), i);
    y2 = y1+1; x2 = x1;
    t1 = sub2ind([nY nX], y1, x1);
    t2 = sub2ind([nY nX], y2, x2);
    M(t1,t1) = M(t1,t1)+1;
    M(t1,t2) = M(t1,t2)-1;
    c(t1,:) = c(t1,:) - vShifts(i,:);
    M(t2,t2) = M(t2,t2)+1;
    M(t2,t1) = M(t2,t1)-1;
    c(t2,:) = c(t2,:) + vShifts(i,:);
end

for i=find(HorizontalPairs)'
    if isnan(hShifts(i,1)); continue; end;
    [y1,x1] = ind2sub(size(HorizontalPairs), i);
    y2 = y1; x2 = x1+1;
    t1 = sub2ind([nY nX], y1, x1);
    t2 = sub2ind([nY nX], y2, x2);
    M(t1,t1) = M(t1,t1)+1;
    M(t1,t2) = M(t1,t2)-1;
    c(t1,:) = c(t1,:) - hShifts(i,:);
    M(t2,t2) = M(t2,t2)+1;
    M(t2,t1) = M(t2,t1)-1;
    c(t2,:) = c(t2,:) + hShifts(i,:);
end

% now we want to anchor one of the tiles to a fixed coordinate. We do this
% for a home tile in the middle, because it is going to be connected; and we set
% its coordinate to a large value, so any non-connected ones can be
% detected. This is why spectral clustering works!!
Huge = 1e6;
HomeTile = sub2ind([nY nX], ceil(nY/2), ceil(nX/2));
M(nTiles+1,HomeTile) = 1;
c(nTiles+1,:) = [Huge, Huge];

Tiny = 1e-4; % for regularization
TileOffset0 = (M+Tiny*eye(nTiles+1, nTiles))\c;

% find tiles that are connected to the home tile 
AlignedOK = (TileOffset0(:,1)>Huge/2);
TileOffset1 = nan(nTiles, 2);
TileOffset1(AlignedOK,:) = TileOffset0(AlignedOK,:)-Huge;
o.RefPos = bsxfun(@minus,TileOffset1, nanmin(TileOffset1))+1;

save o1 o



%% now we align on all other rounds.

% linear shift
o.RelativePos = nan(o.nRounds+o.nExtraRounds, 2, nTiles, nTiles);
% point cloud transformation matrices, from ref round to neighbors
% actually we will compute this later for each base
%o.PcTransform = cell(o.nRounds+o.nExtraRounds, nTiles, nTiles);
%% that previous line in its own section to avoid accidentally deleting (happens a lot)
for r=1:o.nRounds+o.nExtraRounds
    for t=Tiles
        [y,x] = ind2sub([nY nX], t);

        if r==rr % no offset for reference round
            o.RelativePos(r, :, t,t) = [0 0];
            continue;
        end
 
        MyTile = imread(o.TileFiles{r,y,x},o.AnchorChannel);
        MySpots = iss_detect_spots(MyTile, oNoGraphics);

        % first align to same tile in reference round
        [shift, cc] = ImRegFft(MyTile, RefTiles(:,:,y,x), 'c', o.CorrThresh, o.MinSize);
        fprintf('\nround %d, tile %d at (%d, %d): shift %d %d, to ref round, cc %f\n', r, t, y, x, shift, cc);
        o.RelativePos(r,:,t,t) = shift;
        %o.PcTransform{r,t,t} = PointCloudRegister(MySpots, RefSpots{t}, shift, o.PcDist);

        
        % if you couldn't align tile to itself, don't bother with neighbors
        if ~isfinite(shift(1))
            continue;
        end
        
        % now get neighbors
        if shift(1)>0 % my tile north of reference round
            yDir = 'n'; y1 = y-1;
        else
            yDir = 's'; y1 = y+1;
        end
        
        if shift(2)>0 % my tile north of reference round
            xDir = 'w'; x1 = x-1;
        else
            xDir = 'e'; x1 = x+1;
        end
        
        
        if y1>=1 && y1<=nY && ~EmptyTiles(y1,x)
            [shifty, ccy] = ImRegFft(MyTile, RefTiles(:,:,y1,x), yDir, o.CorrThresh, o.MinSize);
            t2 = sub2ind([nY nX], y1, x);
            fprintf('round %d, tile %d: shift %d %d, to %s ref tile %d, cc %f\n', r, t, shifty, yDir, t2, ccy);
            o.RelativePos(r,:,t,t2) = shifty;
            %o.PcTransform{r,t,t2} = PointCloudRegister(MySpots, RefSpots{t2}, shifty, o.PcDist);
        end
        if x1>=1 && x1<=nX && ~EmptyTiles(y,x1)
            t2 = sub2ind([nY nX], y, x1);
            [shiftx, ccx] = ImRegFft(MyTile, RefTiles(:,:,y,x1), xDir, o.CorrThresh, o.MinSize);
            fprintf('round %d, tile %d: shift %d %d, to %s ref tile %d, cc %f\n', r, t, shiftx, xDir, t2, ccx);
            o.RelativePos(r,:,t,t2) = shiftx;
            %o.PcTransform{r,t,t2} = PointCloudRegister(MySpots, RefSpots{t2}, shiftx, o.PcDist);
        end
        if y1>=1 && y1<=nY && x1>=1 && x1<=nX && ~EmptyTiles(y1,x1)
            t2 = sub2ind([nY nX], y1, x1);
            [shiftyx, ccyx] = ImRegFft(MyTile, RefTiles(:,:,y1,x1), [yDir xDir], o.CorrThresh, o.MinSize);
            fprintf('round %d, tile %d: shift %d %d, to %s ref tile %d, cc %f\n', r, t, shiftyx, [yDir xDir], t2, ccyx);
            o.RelativePos(r,:,t,t2) = shiftyx;
            %o.PcTransform{r,t,t2} = PointCloudRegister(MySpots, RefSpots{t2}, shiftyx, o.PcDist);
        end

      
    end
    save o2 o
end

%% now make background image

MaxTileLoc = max(o.RefPos);
BigDapiIm = zeros(ceil((MaxTileLoc + o.TileSz)/o.DapiScaleFac), 'uint16');

for t=Tiles
    if ~isfinite(o.RefPos(t,1)); continue; end
    LocalDapiIm = imread(o.TileFiles{o.ReferenceRound,t}, o.DapiChannel);
    BigDapiIm(floor(o.RefPos(t,1)/o.DapiScaleFac)+(1:o.TileSz/o.DapiScaleFac), ...
        floor(o.RefPos(t,2)/o.DapiScaleFac)+[1:o.TileSz/o.DapiScaleFac]) ...
        = imresize(LocalDapiIm, 1/o.DapiScaleFac);
end

imwrite(BigDapiIm, [o.OutputDirectory '\background_image.tif']);