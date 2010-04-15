########################################
######## Draw Copy Number Graph ########
########################################

readcount <- function(name=NULL){

	############################ read data ##############################
	name <- read.table(name,sep='\t');
	inFile <- as.character(name$V1[1])
	outFileL <- as.character(name$V2[1])
	outFileR <- as.character(name$V3[1])
	inFile_n <- as.character(name$V4[1])
	outFileL_n <- as.character(name$V5[1])
	outFileR_n <- as.character(name$V6[1])

	# control the flow
	tumor <- 1
	normal <- 1
	if(is.na(inFile))
	  tumor <- 0
	if(is.na(inFile_n))
	  normal <- 0


	# tumor
	if(tumor == 1){
		a <- read.table(inFile, sep="\t", quote="", comment="")
		a_ <- a$V3
		a_axis <- a$V2
		
		aL <- read.table(outFileL, sep="\t", quote="", comment="")
		aR <- read.table(outFileR, sep="\t", quote="", comment="")
		aNeighbor <- rbind(aL, aR)
		aNeighbor_ <- aNeighbor$V3
		aNeighbor_axis <- aNeighbor$V2
	}

	# normal
	if(normal == 1){
		aN <- read.table(inFile_n, sep="\t", quote="", comment="")
		aN_ <- aN$V3
		a_axisN <- aN$V2

		aLN <- read.table(outFileL_n, sep="\t", quote="", comment="")
		aRN <- read.table(outFileR_n, sep="\t", quote="", comment="")
		aNeighborN <- rbind(aLN, aRN)
		aNeighborN_ <- aNeighborN$V3
		aNeighbor_axisN <- aNeighborN$V2
	}


	# read the file to get the picture name, title and axis
	data_name <- as.character(name$V1[2])
	picName <- as.character(name$V2[2])
	chromosome <- name$V3[2]

	# number of the annotations
	num <- 4

	################################ annotation #############################
	############### segmental Duplication
	tmp <- name$V1[4]
	Read_Annotation(tmp) -> seg
	seg_ <- as.numeric();
	if(class(seg)!='try-error'){
		for(i in 1:length(seg$Start)){
			seg_ = c(seg_, seg$Start[i]:seg$End[i]);
		}
	}

	############### repeat mask
	tmp <- name$V2[4]
	Read_Annotation(tmp) -> rep

	############### dgv
	tmp <- name$V3[4]
	Read_Annotation(tmp) -> dgv

	############### gene
	tmp <- name$V4[4]
	Read_Annotation(tmp) -> gene

	############################# normalize data by segmental duplication ###################
	# tumor:
	if(tumor == 1){
		normalization(aNeighbor_axis, aNeighbor_, seg_) -> aNeighbor_median_old
		a_ <- 2*a_/aNeighbor_median_old
		aNeighbor_ <- 2*aNeighbor_/aNeighbor_median_old
		a_median <- median(a_)
		aNeighbor_median <- 2
	}

	# normal:
	if(normal == 1){
		normalization(aNeighbor_axisN, aNeighborN_, seg_) -> aNeighborN_median_old
		aN_ <- 2*aN_/aNeighborN_median_old
		aNeighborN_ <- 2*aNeighborN_/aNeighborN_median_old
		aN_median <- median(aN_)
		aNeighborN_median <- 2
	}
	
	############################## not to consider those in annotation segmental duplication #######
	#tumor
	if(tumor == 1){
		aNeighbor_NoSeg <- aNeighbor_[! aNeighbor_axis %in% seg_]
		aNeighbor_NoSeg_axis <- aNeighbor_axis[! aNeighbor_axis %in% seg_]
		aNeighbor_Seg <- aNeighbor_[aNeighbor_axis %in% seg_]
		aNeighbor_Seg_axis <- aNeighbor_axis[aNeighbor_axis %in% seg_]
	}
	#normal
	if(normal == 1){
		aNeighborN_NoSeg <- aNeighborN_[! aNeighbor_axisN %in% seg_]
		aNeighborN_NoSeg_axis <- aNeighbor_axisN[! aNeighbor_axisN %in% seg_]
		aNeighborN_Seg <- aNeighborN_[aNeighbor_axisN %in% seg_]
		aNeighborN_Seg_axis <- aNeighbor_axisN[aNeighbor_axisN %in% seg_]
	}

	############################### printing start here ################################################
	cex_ <- 0.6
	pch_ <- 16
	lwd_ <- 3

	png(picName)

	if(tumor == 1 && normal == 1)
	    nf <- layout(matrix(c(1:4),2,2,byrow=TRUE), c(2,2), c(3,1), TRUE)
	else
  		nf <- layout(matrix(c(1:2),nrow=2,ncol=1,byrow=TRUE), c(4), c(3,1), TRUE)
	layout.show(nf)




	if(tumor == 1){
		if(normal == 1)
			par(mar=c(3,5,5,0))
		else
			par(mar=c(3,5,5,3))
			
		Printing_Graph(a_, a_axis, "red", a_median, "green", aNeighbor_NoSeg, aNeighbor_NoSeg_axis, "blue", aNeighbor_Seg, aNeighbor_Seg_axis, "grey", aNeighbor_median, "black", "Tumor", pch_, cex_, lwd_)
	}

	if(normal == 1){
		if(tumor ==1 )
			par(mar=c(3,2,5,3))
		else
			par(mar=c(3,5,5,3))

		Printing_Graph(aN_, a_axisN, "red", aN_median, "green", aNeighborN_NoSeg, aNeighborN_NoSeg_axis, "blue", aNeighborN_Seg, aNeighborN_Seg_axis, "grey", aNeighborN_median, "black", "Normal", pch_, cex_, lwd_)
	}

	lwd_ = 7

	if(tumor == 1){
		if(normal == 1)
			par(mar=c(0,5,0,0))
		else
			par(mar=c(0,5,0,3))
			
		##################### segmental Duplication
		Draw_Annotation_First(seg, aNeighbor_axis, num, "grey", "purple", 1, lwd_, "Segmental Duplication", num-0.4, 0.8)
		
		################# repeat Mask
		Draw_Annotation(rep, aNeighbor_axis, num-1, "grey", "green", 1, lwd_, "Repeat Mask", num-1.4, 0.8)

		################# gene
		Draw_Annotation(gene, aNeighbor_axis, num-2, "grey", "yellow", 1, lwd_, "Gene", num-2.4, 0.8)

		################# dgv
		Draw_Annotation(dgv, aNeighbor_axis, num-3, "grey", "black", 1, lwd_, "Database of Genomic Variants", num-3.4, 0.8)
	}

	if(normal == 1){
		if(tumor == 1)
			par(mar=c(0,2,0,3))
		else
			par(mar=c(0,5,0,3))
		##################### segmental Duplication
		Draw_Annotation_First(seg, aNeighbor_axis, num, "grey", "purple", 1, lwd_, "Segmental Duplication", num-0.4, 0.8)
		
		################# repeat Mask
		Draw_Annotation(rep, aNeighbor_axis, num-1, "grey", "green", 1, lwd_, "Repeat Mask", num-1.4, 0.8)
		
		################# gene
		Draw_Annotation(gene, aNeighbor_axis, num-2, "grey", "yellow", 1, lwd_, "Gene", num-2.4, 0.8)

		################# dgv
		Draw_Annotation(dgv, aNeighbor_axis, num-3, "grey", "black", 1, lwd_, "Database of Genomic Variants", num-3.4, 0.8)
	}

	# main title
	if(is.na(data_name))
		main_title <- chromosome
	else
  		main_title <- paste(data_name,chromosome,sep=" ")
	mtext(main_title, outer=TRUE, line=-2, cex=1.5)

	dev.off()
}

Read_Annotation = function(var)
{
	file_name <- as.character(var)
	data <- try(read.table(file_name, sep='\t', header=TRUE))
	#if(class(data)=='try-error'){
	#	data <- NULL
	#} else if(gregexpr(",",data$V1[1])>0){
	#	data <- try(read.table(file_name, sep=","));
	#}
	data
}

normalization = function(x, y, annot)
{
	y_ <- y[! x %in% annot]
	mean_y_ <- mean(y_)
	sd_y_ <- sd(y_)
	new_y <- y_[y_ > mean_y_ - sd_y_ & y_ < mean_y_ + sd_y_]
	median_new_y <- median(new_y)
	median_new_y
}

Printing_Graph = function(y,x,col_data,med,col_med,y1,x1,col_data1,y2,x2,col_data2,med_,col_med_,title_,pch_,cex_,lwd_)
{
	plot(y ~ x, col = col_data, xlim = c(min(c(x1,x2)),max(c(x1,x2))), ylim = c(0,4), xlab = "Base", ylab = "Copy Number", pch = pch_, cex = cex_)
	points(y1~x1, col=col_data1, pch=pch_, cex=cex_)
	points(y2~x2, col=col_data2, pch=pch_, cex=cex_)
	
	# lines the median
	segments(min(c(x1,x2)), med_, min(x), med_, col=col_med_, lwd=lwd_)
	segments(max(x), med_, max(c(x1,x2)), med_, col=col_med_, lwd=lwd_)
	segments(min(x), med, max(x), med, col=col_med, lwd=lwd_)
	
	title(title_, cex.main=1.1, line = 1)
}

Draw_Annotation = function(data,x,y,col1,col2,lwd1,lwd2,name,height,cex_)
{
	segments(min(x),y,max(x),y,col=col1,lwd=lwd1)
	if(length(data$Start)>=1){
		for(i in 1:length(data$Start)){
			segments(data$Start[i], y, data$End[i], y, col=col2, lwd=lwd2)
		}
	}
	text((min(x)+max(x))/2, height, name, cex=cex_)
}

Draw_Annotation_First = function(data,x,y,col1,col2,lwd1,lwd2,name,height,cex_)
{
	test_coords <- xy.coords(min(x):max(x),y,recycle=TRUE)
	plot(test_coords$x,test_coords$y,col=col1,xlim=c(min(x),max(x)),ylim=c(0,y),axes=FALSE,xlab="",ylab="",type="l",lwd=lwd1)
	if(length(data$Start)>=1){
		for(i in 1:length(data$Start)){
			segments(data$Start[i], y, data$End[i], y, col=col2, lwd=lwd2)
		}
	}
	text((min(x)+max(x))/2, height, name, cex=cex_)
}
