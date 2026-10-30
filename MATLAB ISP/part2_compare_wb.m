% PART2_COMPARE_WB  White balance gain comparison for Assignment 1.
%
%   Computes the white balance gains with StudentFunctions.calculateWhiteBalance
%   for every ColorChecker capture in dataset/Input/DNG and shows each
%   ColorChecker processed with
%     - gains [1, 1, 1] (no white balance), with patches 21 and 22 marked
%     - the calculated gains
%   The figures are saved to report/figures and labelled with the gains used.
%
%   Requires the Image Processing Toolbox (rawread, rawinfo, demosaic).
%   Run from any folder: the paths are relative to this file.

clear; close all;

ispDir  = fileparts(mfilename('fullpath'));
repoDir = fileparts(ispDir);
dngDir  = fullfile(repoDir, 'dataset', 'Input', 'DNG');
outDir  = fullfile(repoDir, 'report', 'figures');
addpath(ispDir);                    % makes +StudentFunctions visible
if ~exist(outDir, 'dir'), mkdir(outDir); end

illuminants = {'D65_1000lux', 'LED4000K_500lux', 'A_100lux'};
nShots = 4;

% Patch boxes used in calculateWhiteBalance (for drawing only).
box21 = [1871 2066 1811 2006];
box22 = [1871 2066 2097 2292];

%% Gains for every capture
gains = zeros(numel(illuminants), nShots, 3);
for i = 1:numel(illuminants)
    for k = 1:nShots
        file = fullfile(dngDir, sprintf('CC_%s_%d.dng', illuminants{i}, k));
        gains(i, k, :) = StudentFunctions.calculateWhiteBalance(readCFA(file));
    end
end

fprintf('\n%-18s %-6s %8s %8s %8s\n', 'Illuminant', 'Shot', 'gain_R', 'gain_G', 'gain_B');
for i = 1:numel(illuminants)
    for k = 1:nShots
        fprintf('%-18s %-6d %8.4f %8.4f %8.4f\n', illuminants{i}, k, squeeze(gains(i, k, :)));
    end
    g = squeeze(mean(gains(i, :, :), 2));
    s = squeeze(std(gains(i, :, :), 0, 2));
    fprintf('%-18s %-6s %8.4f %8.4f %8.4f   (std %.4f / %.4f)\n\n', ...
        illuminants{i}, 'mean', g, s(1), s(3));
end

%% Comparison figures (first shot of each illuminant)
for i = 1:numel(illuminants)
    file = fullfile(dngDir, sprintf('CC_%s_1.dng', illuminants{i}));
    cfa  = readCFA(file);
    g    = StudentFunctions.calculateWhiteBalance(cfa);

    variants = {[1 1 1], g};
    labels   = {'gains [1, 1, 1]', ...
                sprintf('calculated gains [%.3f, %.3f, %.3f]', g)};

    fig = figure('Name', illuminants{i}, 'Position', [100 100 1400 520]);
    tl  = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    for v = 1:2
        nexttile(tl);
        imshow(renderPreview(cfa, variants{v}));
        title(sprintf('%s: %s', strrep(illuminants{i}, '_', ' '), labels{v}));
        if v == 1
            hold on;
            drawBox(box21); drawBox(box22);
            hold off;
        end
    end
    exportgraphics(fig, fullfile(outDir, sprintf('CC_%s_wb_matlab.png', illuminants{i})));
end

%% Local functions

function cfa = readCFA(file)
% Raw GBRG CFA data, black level subtracted and normalised to [0, 1].
    info = rawinfo(file);
    raw  = double(rawread(file));
    blk  = double(info.ColorInfo.BlackLevel);
    wht  = double(info.ColorInfo.WhiteLevel);
    cfa  = (raw - mean(blk(:))) / (wht - mean(blk(:)));
    cfa  = max(cfa, 0);
end

function rgb = renderPreview(cfa, g)
% Apply white balance gains to the GBRG mosaic, demosaic and gamma-encode.
    wb = cfa;
    wb(1:2:end, 2:2:end) = wb(1:2:end, 2:2:end) * g(3);   % B
    wb(2:2:end, 1:2:end) = wb(2:2:end, 1:2:end) * g(1);   % R
    wb(1:2:end, 1:2:end) = wb(1:2:end, 1:2:end) * g(2);   % G
    wb(2:2:end, 2:2:end) = wb(2:2:end, 2:2:end) * g(2);   % G
    wb  = min(wb, 1);
    rgb = double(demosaic(uint16(wb * 65535), 'gbrg')) / 65535;
    G   = rgb(:, :, 2);
    rgb = min(rgb / prctile(G(:), 99.5), 1) .^ (1 / 2.2);
end

function drawBox(box)
    rectangle('Position', [box(3), box(1), box(4) - box(3), box(2) - box(1)], ...
        'EdgeColor', 'r', 'LineWidth', 2);
end
