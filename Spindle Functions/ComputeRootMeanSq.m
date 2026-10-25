function [rms_signal] = ComputeRootMeanSq(signal,wdwT,sampling_freq,smoothingWdw)

rms = zeros(size(signal));
bins = round(wdwT*sampling_freq); %bins to sum across
if mod(bins,2)==0 %iseven
    bins = bins+1;
end
bL = (bins-1)/2;
for idt = 1:length(rms)
    xt = (idt-bL):(idt+bL);
    if and(min(xt)>=1, max(xt)<=length(rms))
        xs = signal(xt);
        rms(idt) = sqrt(mean(xs.^2));
    end
end
rms_signal.raw = rms;

if smoothingWdw>0
    bins = round(smoothingWdw*sampling_freq);
    Wb = gausswin(bins);
    y = conv(rms,Wb,'same');
else
    y = [];
end
rms_signal.smooth = y;
return