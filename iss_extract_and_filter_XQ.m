function o = iss_extract_and_filter_XQ(o)

% parpool
o.TileFiles = [];
for r = 1:o.nRounds+o.nExtraRounds
    imfile = fullfile(o.InputDirectory, [o.Filename{r}, '.czi']);
    if ~exist(o.TileDirectory, 'dir') 
        mkdir(o.TileDirectory);
    end
    
    % construct a Bio-Formats reader with the Memoizer wrapper
    bfreader = loci.formats.Memoizer(bfGetReader(), 0);
    % initiate reader
    bfreader.setId(imfile);
     
    % get some basic image metadata
    [nSeries, nSerieswPos, nChannels, nZstacks, xypos, pixelsize] = ...
        get_ome_tilepos(bfreader);
    scene = nSeries/nSerieswPos;
    
    bfreader.close()
    
    for c = 1:nChannels
        % structuring element for top-hat
        if c == o.DapiChannel
            SE = strel('disk', round(8/pixelsize));     % DAPI
        else
            SE = strel('disk', round(1/pixelsize));
        end
        
        parfor t = 1:nSerieswPos  
            % a new reader per worker
            bfreader = javaObject('loci.formats.Memoizer', bfGetReader(), 0);
            % use the memo file cached before
            bfreader.setId(imfile);
            
            bfreader.setSeries(scene*t-1);
            
            % read z stacks
            I = cell(nZstacks,1);
            for z = 1:nZstacks
                iPlane = bfreader.getIndex(z-1, c-1, 0)+1;
                I{z} = bfGetPlane(bfreader, iPlane);
            end
            bfreader.close();
            
            % focus stacking
            IFS = fstack_modified(I);
            
            % tophat
            IFS = imtophat(IFS, SE);
            
            % write stack image
            imwrite(IFS,...
                fullfile(o.TileDirectory,...
                [o.Filename{r}, '_t', num2str(t), '.tif']),...
                'tiff', 'writemode', 'append');
        end
        fprintf('Round %d channel %d finished.\n', r, c);
    end        
    
    % tile image names in grid
    [~, img_name_grid] = tilepos2grid(xypos,...
        fullfile(o.TileDirectory, [o.Filename{r} '_t']), '.tif');
    [nY, nX] = size(img_name_grid);
    img_name_grid(strcmp(img_name_grid, 'empty.tif')) = {''};
    img_name_grid = reshape(img_name_grid, nY, nX);
    
    o.TileFiles = cat(3, o.TileFiles, img_name_grid);
end

delete(gcp('nocreate'))
o.TileFiles = permute(o.TileFiles, [3,1,2]);

end
