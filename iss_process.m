%% top level script for analyzing in situ sequencing data
% 
% Kenneth D. Harris, 29/3/17
% GPL 3.0 https://www.gnu.org/licenses/gpl-3.0.en.html
 
% set parameters to default values
o = iss_options;

% make top-hat filtered tile files (for now a dummy function since this has
% already been done)
o = iss_extract_and_filter(o);

% register tiles against their neighbors
o = iss_register(o);

% find spots and get their fluorescence values
[GlobalYX, SpotColors, Isolated] = iss_find_spots(o);
%GlobalYX = GoodGlobalYX; SpotColors = GoodSpotColors; Isolated = GoodIsolated;

% assign them to cells
[Genes, Codes, MaxScore, Intensity] = iss_call_spots(o, SpotColors, Isolated);

% this would make a figure before finishing 
% ScoreThresh = .85; ShowMe = (MaxScore>ScoreThresh);
% figure(100); 
% iss_make_figure(o, GlobalYX(ShowMe,:), Genes(ShowMe));

% find extra genes in final round (Sst and Npy)
[ExtraGlobalYX, ExtraGenes] = iss_single_genes(o);
%ExtraGlobalYX = ExtraGoodGlobalYX; ExtraGenes = ExtraGoodGene;

% now put everything together
FinalYX  = [GlobalYX ; ExtraGlobalYX];
FinalGenes = [Genes; ExtraGenes];
FinalMaxScore = [MaxScore ; ones(length(ExtraGenes),1)];

%% produce output figure
if o.Graphics
    figure(1)
    ShowMe = (FinalMaxScore>.9);
    iss_make_figure(o, FinalYX(ShowMe,:), FinalGenes(ShowMe));
   
end

%% save it
savefig([o.OutputDirectory '\iss.fig']);

% and save data
save([o.OutputDirectory '\iss.mat'], 'FinalYX', 'FinalGenes', 'FinalMaxScore');

