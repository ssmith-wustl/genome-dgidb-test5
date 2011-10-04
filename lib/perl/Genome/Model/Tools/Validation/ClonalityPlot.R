drawPlot <- function(z1, cn, xchr, additional_plot_points, additional_plot_points_cn, ptcolor, circlecolor, cncircle=0){
  plot.default(x=(z1$V11), y=(z1$V9+z1$V10), log="y",
               type="p", pch=19, cex=0.4, col="#00000000",
               xlim=c(-1,101), ylim=c(5,absmaxx+5),
               axes=FALSE, ann=FALSE, xaxs="i", yaxs="i");
  
  points(y=(cn$V9+cn$V10), x=(cn$V11), type="p", pch=19, cex=0.4, col=ptcolor);
  points(y=(xchr$V9+xchr$V10),x=(xchr$V11),type="p",pch=2,cex=0.8,col=ptcolor);
  ##add in highlight of points selected for by script input
  if(length(additional_plot_points) > 1) {
    points(x=additional_plot_points$V2,y=additional_plot_points$V3,type="p",pch=7,cex=0.8,col="#555555FF");
  }
  axis(side=2,las=1,tck=0,lwd=0,cex.axis=0.6,hadj=0.5);
  for (i in 2:length(axTicks(2)-1)) {
    lines(c(-1,101),c(axTicks(2)[i],axTicks(2)[i]),col="#00000022");
  }
  rect(-1, 5, 101, axTicks(2)[length(axTicks(2))]*1.05, col = "#00000011",border=NA); #plot bg color
  if(cncircle != 0){
    ##add cn circle
    points(x=c(97),y=c((absmaxx+5)*0.70),type="p",pch=19,cex=3,col=circlecolor);
    text(c(97),y=c((absmaxx+5)*0.70), labels=c(cncircle), cex=1, col="#FFFFFFFF")
  }
}
