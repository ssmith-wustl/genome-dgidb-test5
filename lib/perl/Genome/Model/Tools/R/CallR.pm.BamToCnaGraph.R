#This file contains code to graph a small region of interest from BamToCna data

graph_cna_region=function(cna_file="",output_file="",chromosome="",region_start="",region_end="",roi_start="",roi_end="",title="",xlab="",ylab="") {

    png(output_file,width=5,height=6,res=300,units="in",type="cairo");
    x<-read.table(cna_file,header=TRUE);    #this assumes a normal bamtocna output file
    x_region <- x[x$CHR==chromosome & x$POS >= region_start & x$POS <= region_end,];
    x_region_roi <- x_region[x_region$POS >= roi_start & x_region$POS <= roi_end,];
    x_region_nonroi <- x_region[x_region$POS < roi_start | x_region$POS > roi_end,];
    plot(x_region_nonroi$POS/1000000,x_region_nonroi$DIFF+2,ylim=c(0,6),col="blue",cex=0.5,pch=19,ylab=ylab,xlab=xlab,main=title);
    points(x_region_roi$POS/1000000,x_region_roi$DIFF+2,ylim=c(0,6),col="red",cex=0.5,pch=19);
    lines(c(roi_start,roi_end)/1000000,c(median(x_region_roi$DIFF+2),median(x_region_roi$DIFF+2)),col="green",lwd=4);
    dev.off();
}


