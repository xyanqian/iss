function o=iss_extract_and_filter(o)
% o=iss_extract_and_filter(o)
%
% takes czi files as input, and produces a top-hat filtered version of each
% one in the o.ImagesDirectory directory. 
%
% also produces cell array of files using full path names: o.TileFiles(r,
% tileY, tileX), with '' meaning that tile is missing.
%
% for now this is just a shell function for the dataset
% 161230_161220KI_3-1, that returns o.TileFiles
% 
% Kenneth D. Harris, 29/3/17
% GPL 3.0 https://www.gnu.org/licenses/gpl-3.0.en.html
 
md = load('A:\Dropbox\Dropbox (Neuropixels)\161230_161220KI_3-1\Stitched\stitchtestmetadata-2');

[nY, nX] = size(md.img_name_grid); 

o.TileFiles = cell(o.nRounds+o.nExtraRounds, nY, nX);
for r=1:o.nRounds+o.nExtraRounds
    for y=1:nY
        for x=1:nX
            if strcmp('empty.tif', md.img_name_grid{y,x})
                o.TileFiles{r,y,x} = ''; 
            else
                f = md.img_name_grid{y,x}; 
                f(5) = num2str(r);
                o.TileFiles{r,y,x} = [o.TileDirectory '\' f];
            end
        end
    end
end