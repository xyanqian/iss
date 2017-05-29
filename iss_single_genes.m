function [ExtraGoodGlobalYX, ExtraGoodGene] = iss_single_genes(o)
% [GlobalYX, Gene] = iss_single_genes(o)
%
% processes additional rounds in which single genes were detected
% non-combinatorially. Outputs are spot positions in global coordinates 
% (see iss_find_spots) and Gene assignments (see iss_call_spots)
% 
% Kenneth D. Harris, 29/3/17
% GPL 3.0 https://www.gnu.org/licenses/gpl-3.0.en.html
 
%% basic variables
rr = o.ReferenceRound;
EmptyTiles = strcmp('', squeeze(o.TileFiles(rr,:,:)));
Tiles = find(~EmptyTiles)';

[nY, nX] = size(EmptyTiles);
nTiles = nY*nX;

%% main loop

for r=o.nRounds+(1:o.nExtraRounds)
    MyRows = find(r==[o.ExtraCodes{:,2}]);
    MyChannels = [o.ExtraCodes{MyRows,3}];
    for t=Tiles(:)'
        if mod(t,10)==0; fprintf('extras for tile %d\n', t); end
        for i=1:length(MyChannels(:))
            c = MyChannels(i);
            ExtraIm = imread(o.TileFiles{r,t}, c); 
            [ExtraRawLocalYX{t,c,r}, ~] = iss_detect_spots(ExtraIm, o);
            ExtraRawGlobalYX{t,c,r} = bsxfun(@plus, ExtraRawLocalYX{t,c,r}, o.RefPos(t,:)-o.RelativePos(r,:,t,t));
            nSpots = size(ExtraRawGlobalYX{t,c,r},1);
            ExtraRawGene{t,c,r} = repmat(o.ExtraCodes(MyRows(i),1), nSpots,1);
            ExtraRawDetectedTile{t,c,r} = repmat(t,nSpots,1);
        end
    end
end

% concatenate big arrays
ExtraAllGlobalYX = vertcat(ExtraRawGlobalYX{:});
ExtraAllDetectedTile = vertcat(ExtraRawDetectedTile{:});
ExtraAllGene = vertcat(ExtraRawGene{:});

% eliminate duplicates (can go straight from all to good here, no nd)
% note that by this stage everything is in global coordinates relative to
% reference frame, which is why we don't need to add to o.RefPos
ExtraAllTile = iss_which_tile(ExtraAllGlobalYX, o.RefPos, o.TileSz);
ExtraGood = (ExtraAllTile==ExtraAllDetectedTile);

ExtraGoodGlobalYX =ExtraAllGlobalYX(ExtraGood,:);
ExtraGoodGene =ExtraAllGene(ExtraGood);

