function wb_gains = calculateWhiteBalance(input_image)
% CALCULATEWHITEBALANCE Chart-based white balance gains.
%
%   wb_gains = calculateWhiteBalance(input_image) returns the white balance
%   gains [gain_R, gain_G, gain_B] computed from the gray patches 21 and 22
%   of an X-Rite ColorChecker Classic captured under the illuminant of
%   interest.
%
%   input_image is the raw Bayer (CFA) image after black level and lens
%   shading correction, i.e. before CFA interpolation. The Pixel 8 Pro
%   sensor uses a GBRG pattern:
%
%       G B G B ...
%       R G R G ...
%
%   If a demosaiced H x W x 3 image is passed instead, the channel means
%   are taken directly from the three planes.

    img = double(input_image);
    [H, W, ~] = size(img);

    % Patch boxes [rowStart rowEnd colStart colEnd], ~80 % of each patch,
    % measured on the 3072 x 4080 ColorChecker captures.
    refSize  = [3072 4080];
    box21    = [1871 2066 1811 2006];   % gray patch 21
    box22    = [1871 2066 2097 2292];   % gray patch 22
    boxWhite = [1871 2066 1229 1424];   % white patch 19 (orientation check)

    % Scale the boxes if the image size differs from the reference.
    scale = [H H W W] ./ [refSize(1) refSize(1) refSize(2) refSize(2)];
    box21    = makeOddStart(round(box21    .* scale));
    box22    = makeOddStart(round(box22    .* scale));
    boxWhite = makeOddStart(round(boxWhite .* scale));

    % The raw image may be rotated 180 degrees depending on how the phone
    % was held. The white patch 19 must be the brightest of the two
    % candidate locations; if not, rotate the image back, which also
    % restores the original GBRG layout.
    rotWhite = [H+1-boxWhite(2) H+1-boxWhite(1) W+1-boxWhite(4) W+1-boxWhite(3)];
    if meanOf(img, rotWhite) > meanOf(img, boxWhite)
        img = rot90(img, 2);
    end

    % Steps 2-4: extract the patches, average per channel, compute gains.
    gains21 = patchGains(extractPatch(img, box21));
    gains22 = patchGains(extractPatch(img, box22));

    % Step 5-6: average the gains of the two patches.
    wb_gains = (gains21 + gains22) / 2;
end

function patch = extractPatch(img, box)
    patch = img(box(1):box(2), box(3):box(4), :);
end

function gains = patchGains(patch)
% Per-channel averages of a patch and the resulting gains (green = 1).
    if size(patch, 3) == 3
        R_avg = mean(patch(:, :, 1), 'all');
        G_avg = mean(patch(:, :, 2), 'all');
        B_avg = mean(patch(:, :, 3), 'all');
    else
        % The patch starts on an odd row/column, so its top-left pixel has
        % the same CFA colour as pixel (1,1) of the image (G in GBRG).
        G1 = patch(1:2:end, 1:2:end);
        B  = patch(1:2:end, 2:2:end);
        R  = patch(2:2:end, 1:2:end);
        G2 = patch(2:2:end, 2:2:end);
        R_avg = mean(R(:));
        G_avg = mean([G1(:); G2(:)]);
        B_avg = mean(B(:));
    end

    gains = [G_avg / R_avg, 1, G_avg / B_avg];
end

function m = meanOf(img, box)
    p = extractPatch(img, box);
    m = mean(p(:));
end

function box = makeOddStart(box)
% Force odd start indices so the patch stays aligned with the CFA pattern.
    box([1 3]) = box([1 3]) - (mod(box([1 3]), 2) == 0);
end
