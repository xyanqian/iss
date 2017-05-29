function [Tile, LocalCoord] = iss_which_tile(Points, TileOrigins, TileSz)
% [Tile, LocalCoord] = WhichTileAmIIn(GlobalCoord, TileOrigins, TileSz)
%
% You have a tiled image that has already been stitched, and the XY coords 
% of the origin of each tile in a global cooridnate system are in
% TileOrigins (size nTiles x 2). All tiles are square of size TileSz
% 
% You have a set of Points in the global coordinate system (nPoints x 2), 
% and you want to know which Tile to find them in (nPoints x 1), and what 
% their LocalCoord in that tile (nPoints x 2)
% 
% sometimes a point is in more than one tile (because overlap) - in this
% case, it will choose the one with the lowest tile index
% 
% NOTE here we assuming coordinates within a tile starting at 0! (matlab usually starts at 1)
% i.e. LocalCoord = GlobalCoord - TileOrigin
% 
% Kenneth D. Harris, 29/3/17
% GPL 3.0 https://www.gnu.org/licenses/gpl-3.0.en.html
 
TileCenters = TileOrigins + TileSz/2 - .5; % .5 because even tile size

% int16 to save memory
iPts = int16(Points);
iTC = int16(TileCenters); % and the .5 will get lost - but it shouldn't matter because margins

% l_infinity distance of each point from each tile center (size nPoints x nTiles)

% SquareDist = max(abs(bsxfun(@minus,Points(:,1),TileCenters(:,1)')), ...
%     abs(bsxfun(@minus,Points(:,2),TileCenters(:,2)')));
SquareDist = max(abs(bsxfun(@minus,iPts(:,1),iTC(:,1)')), ...
    abs(bsxfun(@minus,iPts(:,2),iTC(:,2)')));

[MinDist, Tile] = min(SquareDist,[],2);
FitsIn = (MinDist<TileSz/2); % is the point actually in the tile? ASSUME SQUARE TILE!
Tile(~FitsIn) = nan; % if no fit, Tile and LocalCoord is nan
LocalCoord = nan(size(Points));
LocalCoord(FitsIn,:) = Points(FitsIn,:) - TileOrigins(Tile(FitsIn),:);

return
