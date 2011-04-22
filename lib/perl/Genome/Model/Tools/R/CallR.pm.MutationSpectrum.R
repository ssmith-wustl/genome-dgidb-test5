#This file contains code to graph a small region of interest from BamToCna data
plot_spectrum=function(spectrum_file="",output_file="",genome="") {
    read.table(spectrum_file,fill=T,header=T,row.names=1)->spectrum;
    spectrum = (spectrum[0:6,]/spectrum['SNVs',1])*100;
    spectrum$Synonomous=c();
    spectrum=as.matrix(t(spectrum));
    pdf(file=output_file,width=6,height=6);
    title = "Mutation Spectrum";
    if(genome!="") {
        title = paste(title,"For",genome);
    }
    barplot(spectrum,beside=T,xlab="Mutation Class",ylim=c(0,100),ylab="Percent of Total Mutations",main=title,col=c("darkorange","darkgreen","purple4","darkred","darkblue","tan4"),space=c(0,0.1));
    dev.off();
}
