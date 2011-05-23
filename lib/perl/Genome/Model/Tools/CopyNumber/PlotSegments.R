## 
## read in the entrypoints file
##
readEntrypoints <- function(file){
  p=read.table(file,sep="\t",quote="",comment.char="#",
    colClasses=c("character","numeric","numeric"))
  return(p)
}

##
## add offsets to entrypoints file
##
addOffsets <- function(df){
  ##starts with chr,len,ploidy
  offsets = c()
  sum = 0
  for(i in 1:length(df[,1])){
    offsets = c(offsets,sum)
    sum = sum + df[i,2]
  }
  df[,4] <- offsets
  return(df)
}


##
## main function - plot the segments
##

plotSegments <- function(chr="ALL", filename, entrypoints, ymax=NULL, ymin=NULL,
                         highlights=NULL, lowRes=FALSE, lowResMin=NULL,
                         lowResMax=NULL, showNorm=FALSE, baseline=2,
                         gainThresh=2.5, lossThresh=1.5, annotationsTop=NULL,
                         annotationsBottom = NULL, plotTitle="",
                         gainColor="red", lossColor="blue", ylabel=""){

  ## add options for plotting just a smaller region - TODO
  xlim = NULL

  ## read in the segments
  segs=read.table(filename,comment.char="#")

  ## read in the entrypoints
  entrypoints=addOffsets(readEntrypoints(entrypoints))
  names(entrypoints) = c("chr","length","ploidy","offset")

  ## if we have regions to highlight, read them in too
  highlightRegions = NULL;
  if(!(is.null(highlights))){
    highlightRegions=read.table(highlights)
  }

  ## if we have annotations, read them in too
  annTopRegions=NULL
  if(!(is.null(annotationsTop))){
    annTopRegions=read.table(annotationsTop)
  }
 annBtmRegions=NULL
  if(!(is.null(annotationsBottom))){
    annBtmRegions=read.table(annotationsBottom)
  }


  ##validate that we have entrypoints for all of our chromosomes
  chrnames = names(table(segs$V1))
  for(i in 1:length(chrnames)){    
    #raise an error if entrypoints and chrs don't match
    if(length(which(entrypoints$chr==chrnames[i])) < 1){
      cat("\nERROR - no entrypoint found for chromosome ",chrnames[i]," found in segs file\n")
      cat("maybe you meant to use the male entrypoints?\n")
      q(save="no")
    }
  }

  
  ## function to expand the size of features
  ## so that they exceed the minimum pixel size on small
  ## plots
  makeVisible <- function(st,sp,minSize=lr.min){
    if((sp-st) < minSize){
      mid=((sp-st)/2)+st
      return(c(mid-(minSize/2),mid+(minSize/2)))
    }
    return(c(st,sp))
  }
  

################################################
  ## plot all chromosomes 
  if(chr=="ALL"){
  
    ## if we haven't set a ymax/ymin, set it to be just
    ## higher than the maximum peaks
    if(is.null(ymax)){
      ymax=max(segs[,5])*1.1
    }
    if(is.null(ymin)){
      ymin=min(segs[,5])*1.1
    }

    ## set the xlim to the width of the genome
    if(is.null(xlim)){
      xlim=c(1,sum(entrypoints$length))
    }else{
      a = segs[which(((segs$V3 >= xlim[1]) & (segs$V3 <= xlim[2])) | ((segs$V2 >= xlim[1]) & (segs$V2 <= xlim[2]))),]
    }    
    
    ## outline the plot
    plot(0, 0, xlim=xlim, ylim=c(ymin,ymax), pch=".",
         ylab=ylabel, xlab="", xaxt="n", cex.lab=1, cex.axis=0.7)

    title(ylab=ylabel,line=2,cex.lab=0.6) 
    
    ## add the title
    if(!(is.null(plotTitle))){
      title(main=plotTitle)
    }
    
    ## draw baselines
    abline(h=baseline,col="grey25")

    
    offsets = as.numeric(entrypoints[,4])
    offsets = append(offsets,sum(entrypoints$length))

    ## draw highlight regions, if specified
    if(!(is.null(highlights))){
      for(i in 1:length(highlightRegions[,1])){
        offset=as.numeric(entrypoints[which(entrypoints$chr==highlightRegions[i,1]),4])
        st=as.numeric(highlightRegions[i,2])+offset
        sp=as.numeric(highlightRegions[i,3])+offset
        
        if(lowRes){
          if((sp-st) > lowResMin){
            d=makeVisible(st,sp,lowResMax)
            st = d[1]
            sp = d[2]
          }
        }
        
        rect(st, ymin*2, sp, ymax*2, col="gold",lwd=0,lty="blank")
      }
    }
  
    
    ## function to actually draw the segments  
    drawSegs <- function(segs,color="black"){

      for(i in 1:length(segs[,1])){
        ## offset is equal to whatever chromosome we're on
        offset=as.numeric(entrypoints[which(entrypoints$chr==segs[i,1]),4])
        st = offset+segs[i,2]
        sp = offset+segs[i,3]

        ## do the lowres expansion if specified
        if(lowRes){
          if((sp-st) > lowResMin){
            d=makeVisible(st,sp,lowResMax)
            st = d[1]
            sp = d[2]
          }
        }

        ## draw the segment
        rect(st, baseline, sp, segs[i,5], col=color,lty="blank")
      }
    }

    
    ## finally, do the drawing:

    ##plot normal
    if(showNorm){
      a2=segs[which((segs[,5] <= gainThresh) & (segs[,5] >=lossThresh)),]
      if(length(a2[,1])>0){
        drawSegs(a2,color="grey")
      }
    }
    ##plot gain
    a2=segs[which(segs[,5] > gainThresh),]
    if(length(a2[,1])>0){
      drawSegs(a2,color=gainColor)
    }
    ##plot loss
    a2=segs[which(segs[,5] < lossThresh),]
    if(length(a2[,1])>0){
      drawSegs(a2,color=lossColor)
    }

    ## draw chromosome labels
    abline(v=0,col="gray75")
    for(i in 1:(length(offsets)-1)){
      abline(v=offsets[i+1],col="gray75")
      text((offsets[i]+offsets[i+1])/2, ymax*0.9, labels= gsub("chr","",entrypoints[i,1]), cex=0.6)
    }

    
    ## add top annotations, if specfied
    if(!(is.null(annotationsTop))){
      ypos = ymax*0.8    
      for(i in 1:length(annTopRegions[,1])){
        offset=as.numeric(entrypoints[which(entrypoints$chr==annTopRegions[i,1]),4])
        st=as.numeric(annTopRegions[i,2])+offset
        sp=as.numeric(annTopRegions[i,3])+offset
        mid=((sp-st)/2)+st

        ##get the height of the peak at this position (if it exists)
        ptop = 0
        peakNum=which((segs[,1] == annTopRegions[i,1]) &
          (segs[,2] <= mid-offset) & (segs[,3] >= mid-offset))

        if(length(peakNum > 0)){
          ptop = max(segs[peakNum,5])+((ymax-baseline)*0.10)
        }        
        
        text(mid,ypos,annTopRegions[i,4],cex=0.5,font=3)        
        lines(c(mid,mid),c(ptop,ypos*.95))
      }
    }
    
    ## add bottom annotations, if specfied
    if(!(is.null(annotationsBottom))){
      ypos = ymin*0.85
      for(i in 1:length(annBtmRegions[,1])){
        offset=as.numeric(entrypoints[which(entrypoints$chr==annBtmRegions[i,1]),4])
        st=as.numeric(annBtmRegions[i,2])+offset
        sp=as.numeric(annBtmRegions[i,3])+offset
        mid=(sp-st)+st

        ##get the height of the peak at this position (if it exists)
        ptop = 0
        peakNum=which((segs[,1] == annBtmRegions[i,1]) &
          (segs[,2] <= mid) & (segs[,3] >= mid))

        if(length(peakNum > 0)){
          ptop = min(segs[peakNum,5])+((ymax-baseline)*0.10)
        }
                
        text(mid,ypos,annBtmRegions[i,4],cex=0.5,font=3)
        lines(c(mid,mid),c(ptop,ypos*.95))
      }
    }

 
    
############################################################
    ## --------single chromosome-----------------
  } else { #chr != "ALL"
  
    ##get this chromosome's entrypoints and segments
    entry=entrypoints[which(entrypoints$chr==chr),]
    segs = segs[which(segs$V1==chr),]

    ## if we haven't set a ymax, set it to be just
    ## higher than the maximum peak
    if(is.null(ymax)){
      ymax=max(segs[,5])*1.1
    }
    if(is.null(ymax)){
      ymin=min(segs[,5])*1.1
    }

    
    ## if there wasn't an xlim value passed in, use the whole chromosome
    ## otherwise, find the sub-region
    if(is.null(xlim)){
      xlim=c(1,entry$length)
    }else{
      segs = segs[which(((segs$V3 >= xlim[1]) & (segs$V3 <= xlim[2])) | ((segs$V2 >= xlim[1]) & (segs$V2 <= xlim[2]))),]
    }


    ##draw the plot region
    plot(0,0,xlim=xlim,ylim=c(ymin,ymax),pch=".",ylab=ylabel, xlab="position (Mb)",xaxt="n",cex.lab=0.8, cex.axis=0.8)

    ##add the title
    if(!(is.null(plotTitle))){
      title(main=plotTitle)
    }

    ## draw baselines
    abline(h=baseline,col="grey25")
 
    ## set the x-axis labels
    axis(1, at=seq(0,entry$length,5e6), cex.axis=0.8)

    ## draw highlight regions if specified
    if(!(is.null(highlights))){
      for(i in 1:length(highlightRegions[,1])){

        st=as.numeric(highlightRegions[i,2])
        sp=as.numeric(highlightRegions[i,3])

        if(lowRes){
          if((sp-st) > lowResMin){
            d=makeVisible(st,sp,lowResMax)
            st = d[1]
            sp = d[2]
          }
        }
        rect(st, ymin*2, sp, ymax*2, col="gold",lwd=0,lty="blank")
      } 
    }
  
    ##function to draw the segments
    drawSegs <- function(segs,color="black"){
      ## draw segments  
      for(i in 1:length(segs[,1])){
        offset=0
        st = offset+segs[i,2]
        sp = offset+segs[i,3]
        
        if(lowRes){
          if((sp-st) > lowResMin){
            d=makeVisible(st,sp,lowResMax)
            st = d[1]
            sp = d[2]
          }
        }
        rect(st,baseline,sp,segs[i,5],col=color,lwd=0,lty="blank")
      }
    }

    
    ## do the plotting
    
    ##plot normal
    if(showNorm){
      a2=segs[which((segs[,5] <= gainThresh) & (segs[,5] >=lossThresh)),]
      if(length(a2[,1])>0){
        drawSegs(a2,color="grey")
      }
    }
    ##plot gain
    a2=segs[which(segs[,5] > gainThresh),]
    if(length(a2[,1])>0){
      drawSegs(a2,color=gainColor)
    }
    ##plot loss
    a2=segs[which(segs[,5] < lossThresh),]
    if(length(a2[,1])>0){
      drawSegs(a2,color=lossColor)
    }  

    ## add top annotations, if specfied
    if(!(is.null(annotationsTop))){
      ypos = ymax*0.8    
      for(i in 1:length(annTopRegions[,1])){
        if(annTopRegions[i,1] == chr){
          st=as.numeric(annTopRegions[i,2])
          sp=as.numeric(annTopRegions[i,3])
          mid=(sp-st)+st

          ##get the height of the peak at this position (if it exists)
          ptop = 0
          peakNum=which((segs[,1] == annTopRegions[i,1]) &
            (segs[,2] <= mid) & (segs[,3] >= mid))
          
          if(length(peakNum > 0)){
            ptop = max(segs[peakNum,5])+((ymax-baseline)*0.05)
          }        
          
          text(mid,ypos,annTopRegions[i,4],cex=0.5,font=3)
          lines(c(mid,mid),c(ptop,ypos*.90))
        }
      }
    }
    ## add btm annotations, if specfied
    if(!(is.null(annotationsBottom))){
      ypos = ymin*0.8    
      for(i in 1:length(annBtmRegions[,1])){
        if(annBtmRegions[i,1] == chr){
          st=as.numeric(annBtmRegions[i,2])
          sp=as.numeric(annBtmRegions[i,3])
          mid=(sp-st)+st

          ##get the height of the peak at this position (if it exists)
          ptop = 0
          peakNum=which((segs[,1] == annBtmRegions[i,1]) &
            (segs[,2] <= mid) & (segs[,3] >= mid))
          
          if(length(peakNum > 0)){
            ptop = min(segs[peakNum,5])+((ymax-baseline)*0.05)
          }        
          
          text(mid,ypos,annBtmRegions[i,4],cex=0.5,font=3)
          lines(c(mid,mid),c(ptop,ypos*.90))
        }
      }
    }

  }
}
