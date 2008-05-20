# -*-Perl-*-

##############################################
# Copyright (C) 2000 Craig S. Pohl
# Washington University, St. Louis
# All Rights Reserved.
##############################################

######################################
# TouchScreen Interface Data Manager #
######################################

package TouchScreen::HlistCode;

use strict;

our %HlistCode;
my $ROW = 0; #-- keep track

#################################
# Configure Hlist to be created #
#################################
sub HListConfig {
    
    my ($frame, $title, @headers) = @_;
    
    my $column = $#headers;
    
    my $tframe = $frame -> Frame() -> pack(-fill=>'x',
					   -anchor=>'n');
    
    
    my $tlabel = $tframe -> Label(-text => $title, -font  => $::bigfont, -borderwidth => 4, -relief => 'raised') -> pack(-fill=>'x');
    my $hframe = $frame -> Frame(-borderwidth => 10,
				 ) -> pack(-expand=>'yes',
					    -fill=>'both'
					   );
    
    $ROW = 0;
    my $hlist = $hframe -> Scrolled('HList',
				    -header => 1, 
				    -columns => $column+1,
				    -selectmode => 'extended',
				    -itemtype => 'text',
				    -selectbackground => 'yellow',
				    -relief => 'sunken',
				    -borderwidth =>  4, 
				    -font => '-*-times-medium-r-*-*-14-*-*-*-*-*-*-*',
				    -scrollbars => 'osoe',
				    ) -> pack(-expand=>'yes',
					      -fill=>'both'
					      );

    
    for my $col (0 .. $column) {
	
	$hlist -> header('create',$col, -text => $headers[$col]);
    }
   
    return $hlist;


} #HListConfig

#################################
# Configure Hlist to be created #
#################################
sub HListConfigMini {
    
    my ($frame, $title, $width, $height, @headers) = @_;
    
    my $column = $#headers;
    
    my $tframe = $frame -> Frame() -> pack(-fill=>'x',
					   -anchor=>'n');
    
    
    my $tlabel = $tframe -> Label(-text => $title, -font  => $::bigfont, -borderwidth => 4, -relief => 'raised') -> pack(-fill=>'x');
    my $hframe = $frame -> Frame(-borderwidth => 5,
				 ) -> pack(-expand=>'yes',
					   -fill=>'x'
					   );
    
    my $hlist = $hframe -> Scrolled('HList',
				    -header => 1, 
				    -columns => $column+1,
				    -selectmode => 'extended',
				    -itemtype => 'text',
				    -selectbackground => 'yellow',
				    -relief => 'sunken',
				    -borderwidth =>  4, 
				    -font => '-*-times-medium-r-*-*-14-*-*-*-*-*-*-*',
				    -scrollbars => 'osoe',
				    -width => $width,
				    -height => $height,
				    ) -> pack(-expand=>'yes',
					      #-fill=>'x'
					      );

    
    for my $col (0 .. $column) {
	
	$hlist -> header('create',$col, -text => $headers[$col]);
    }

    return $hlist;


} #HListConfigMini




###############################
# Add Mininum Entry to Canvas #
###############################
sub AddEntryMin {
	    
    my ($hlist, $barcode_ref,$barcode_desc, $color) = @_;

    my $text_type = 'text';
    
    #Add new row to HList
    my $row = $hlist->addchild("");
    
    #Create Entry Style
    my $text_style = $hlist->ItemStyle($text_type,-pady => 1, -padx => 1, -font => $::medfont);
    #Insert Scanned Number
    $hlist->itemCreate($row, 0,-itemtype => $text_type,-style => $text_style,-text => $row+1);
    
    # Insert Barcode info into HList and set color for preschedule status
    $text_style->configure(-bg => $color);
    $hlist->itemCreate($row, 1,-itemtype => $text_type,-style => $text_style,-text => $barcode_desc);
    
    #Configure Status button and HList entry
    my $frame = $hlist->Frame->pack(-side => 'top');
    my $status_button=$frame->Button->pack(-side => 'top');
    my $status_text = 'Pass';
    $status_button -> configure(-textvariable => \$status_text, -bg => 'green', -height => 2, -width =>8,  -command => [\&StatusControl, \$status_button, \$status_text, $barcode_ref]);
    
    #Create window style to place button in
    my $window_type = 'window';
    my $button_style = $hlist->ItemStyle($window_type);
    $hlist->itemCreate($row, 2,-itemtype => $window_type,-style => $button_style,-widget => $frame);
    
    return($row);
} #AddEntryMin	

###############################
# Add Mininum Entry to Canvas #
###############################
sub IniRow {
	    
    my ($hlist) = @_;

    my $text_type = 'text';
    
    #Add new row to HList
    $hlist->add($ROW);

    #Create Entry Style
    my $text_style = $hlist->ItemStyle($text_type,-pady => 1, -padx => 1, -font => $::medfont);
    #Insert Scanned Number
    $hlist->itemCreate($ROW, 0,-itemtype => $text_type,-style => $text_style,-text => $ROW+1);
    
    return $ROW++;
} #IniRow	

sub UnIniRow{
    my ($hlist) = @_;

    #Add new row to HList
    $hlist->deleteEntry(--$ROW);
    1;
}

###############################
# Add Mininum Entry to Canvas #
###############################
sub AddRowEntry {
	    
    my ($hlist,$barcode_desc, $color, $col) = @_;

    my $text_type = 'text';
    
    #Add new row to HList
    my $row = $hlist->addchild("");
    
    #Create Entry Style
    my $text_style = $hlist->ItemStyle($text_type,-pady => 1, -padx => 1, -font => $::medfont);
    #Insert Scanned Number
    $hlist->itemCreate($row, 0,-itemtype => $text_type,-style => $text_style,-text => $row+1);
    
    # Insert Barcode info into HList and set color for preschedule status
    $text_style->configure(-bg => $color);
    $hlist->itemCreate($row, ($col ? $col : 1),-itemtype => $text_type,-style => $text_style,-text => $barcode_desc);
    
    return $row;
} #AddEntryMin	
###############################
# Add Mininum Entry to Canvas #
###############################
#my $rightside=0;
my $left=0;
sub AddEntry {
	    
    my ($hlist,$barcode_desc, $color, $row, $col) = @_;

    my $text_type = 'text';
    
    $left = 0 if $col <= 1;
    #Create Entry Style
    my $text_style = $hlist->ItemStyle($text_type,-pady => 1, -padx => 1, -font => $::medfont);
    # Insert Barcode info into HList and set color for preschedule status
    $text_style->configure(-bg => $color);
    $hlist->itemCreate($row, $col,-itemtype => $text_type,-style => $text_style,-text => $barcode_desc);

    my $row_width = 0 ;
    foreach my $c (0 .. $hlist->cget(-columns)-1)
    {
        if ($c == $col)
        {
            $left += $hlist->columnWidth($c);
        }
#        print $c." ".$hlist->columnWidth($c)."\n";
        $row_width += $hlist->columnWidth($c);
    }
    
#    print "row:".$row." ".$left." ".$hlist->width." ".(($left/$row_width)-($hlist->columnWidth($col)/$row_width))."\n";
    $hlist->xview(moveto => (($left/$row_width)-($hlist->columnWidth($col)/$row_width)));

    if($col <= 1){
        $hlist->yview(moveto => 1);
    }

#    if($col <= 1){
#	$rightside = 0;
#	$hlist->xview(moveto => 0);
#    }
#    my $x = $hlist->Subwidget('xscrollbar');
#    my ($xstart, $xend) = $x->get;
#    my $offset = $xend - $xstart;
#    $rightside += $offset * ($hlist->columnWidth($col)/$hlist->width);
#    if($rightside > $xend - (.65*$offset)){
#	$hlist->xview(moveto => ($rightside - .65*($xend-$xstart)));
#    }
    return;
} #AddEntryMin	


sub AddScrollBox {

    my ($hlist, $row, $col) = @_;

    my $text_type = 'text';
    #Configure Status button and HList entry
    my $frame = $hlist->Frame->pack(-side => 'top');
    my $status_button=$frame->Scrolled('Listbox',
				       -scrollbars => 'osoe')->pack(-side => 'top');
    $status_button -> configure(-height => 4, -width =>25);
    
    #Create window style to place button in
    my $window_type = 'window';
    my $button_style = $hlist->ItemStyle($window_type);
    $hlist->itemCreate($row, $col,-itemtype => $window_type,-style => $button_style,-widget => $frame);

    $HlistCode{$row} = $status_button;
    
}


sub Insert {
    
    my ($row, $text) = @_;

    $HlistCode{$row} -> insert('end', $text);
    
}

###############################
# Add Mininum Entry to Canvas #
###############################
sub AddStatus {
	    
    my ($hlist, $row, $col, $status) = @_;

    my $text_type = 'text';
    #Configure Status button and HList entry
    my $frame = $hlist->Frame->pack(-side => 'top');
    my $status_button=$frame->Button->pack(-side => 'top');
    $status_button -> configure(-textvariable => $status, -bg => 'green', -height => 2, -width =>6,  -command => [\&StatusControl, \$status_button, $status]);
    
    #Create window style to place button in
    my $window_type = 'window';
    my $button_style = $hlist->ItemStyle($window_type);
    $hlist->itemCreate($row, $col,-itemtype => $window_type,-style => $button_style,-widget => $frame);
    
    
} #AddEntryMin	

###############################################
# Create special entry with input capablities #
###############################################
sub AddEntryInput {
	
    my ($hlist, $barcode_mgr, $barcode, $barcode_desc, $color) = @_;
    my $text_type = 'text';
   
    # Check Multi Mode Status to Determine if scanning new entry or updating a current entry
    if($barcode_mgr -> MultiMode) {
  	    
	my $barcode_ref = $barcode_mgr -> AddBarcode($barcode,$barcode_desc);

	$barcode_mgr -> SetBarcodeInfo('MultiMode', 0);
	
	#Create Minimum entry set
	my $row = &AddEntryMin($hlist, $barcode_ref, $barcode_ref->BarcodeDescription,$color);
			    
	#Configure Input Entry
	my $inputprocess = $barcode_mgr->InputProcess;
	my $bg_color='red';
	my $rec_style = $hlist->ItemStyle($text_type,-pady => 8, -padx => 1, -bg => $bg_color);
	$hlist->itemCreate($row, 3,-itemtype => $text_type,-style => $rec_style,-text => $inputprocess);
	$::InputRef = $rec_style;
    }
    else {

	my $barcode_ref = $barcode_mgr -> ActiveBarcode;
	$::InputRef -> configure( -bg => 'green');
	$barcode_mgr -> SetBarcodeInfo('MultiMode',1);
	$barcode_ref -> AddInputBarcode($barcode_ref->Barcode);
    }
} #AddEntryInput

####################################
# Create specail entry to add data #
####################################
sub AddEntryData {
	    
    my ($hlist, $barcode_mgr, $barcode, $barcode_desc, $color) = @_;
       
    #Create Minimum entry set
    my $barcode_ref = $barcode_mgr -> AddBarcode($barcode,$barcode_desc);
    
    #Create Minimum entry set
    my $row = &AddEntryMin($hlist, $barcode_ref, $barcode_ref->BarcodeDescription,$color);
    
    my $window_type = 'window';
    my $button_style = $hlist->ItemStyle($window_type,-pady => 1, -padx => 1);

    my $datainfo = $barcode_mgr -> DataInfo;
    my $i = 0;
    my $ebuttons;
    my $frame = $hlist -> Frame -> pack;
    foreach my $info (keys %{$datainfo}) {
	
	my $data = $datainfo->{$info}->{'Default'};
	$barcode_ref -> SetData($info, \$data);
	my $lov = $datainfo -> {$info}->{'ListOfValues'};
	my $desc = $datainfo -> {$info}->{'Description'};
	$ebuttons = $frame -> BrowseEntry(-label => $desc, -variable => \$data, -choices => $lov, -browsecmd => [\&EnterData, \$data]) -> pack(-side => 'top', -anchor => 'e');
    }
    $hlist->itemCreate($row, 3,-itemtype => $window_type,-style => $button_style,-widget => $frame);
    
	
} #AddEntryData

####################################
# Create specail entry to add data #
####################################
sub AddDataInfo {
	    
    my ($hlist, $row, $col, $label, $lov, $data, $brwse_cmd, $validation_cmd) = @_;
           
    my $window_type = 'window';
    my $button_style = $hlist->ItemStyle($window_type,-pady => 1, -padx => 1);

    #------- determine the command!
    my $cmd;
    if(!$brwse_cmd && $validation_cmd){
	
	$cmd = $validation_cmd;
    }
    elsif($brwse_cmd && !$validation_cmd){
	$cmd = $brwse_cmd;
    }
    else{
	$cmd = sub{
	    my $value = shift;
	    &$brwse_cmd($value);
	    &$validation_cmd($value);
	}
    }
    my $i = 0;
    my $frame = $hlist -> Frame -> pack;
    if(defined $brwse_cmd) {
	$frame -> BrowseEntry(-label => $label, -variable => $data, -choices => $lov, 
			      -browsecmd => [\&$brwse_cmd, $data]) -> pack(-side => 'top', -anchor => 'e');
    }
    else {
	$frame -> BrowseEntry(-label => $label, -variable => $data, -choices => $lov, 
			      -browsecmd => [\&EnterData, $data]) -> pack(-side => 'top', -anchor => 'e');
    }
    $hlist->itemCreate($row, $col, -itemtype => $window_type,-style => $button_style,-widget => $frame);
    	
} #AddDataInfo


sub PSEDataInfo{
    #- for the new processing framework, we're hacking up the old one
    my ($hlist, $row, $col, $param_name, $pse, $options, $validation_cmd) = @_;
    
    my $window_type = 'window';
    my $button_style = $hlist->ItemStyle($window_type,-pady => 1, -padx => 1);

    #------- determine the command!
    my $cmd;
    my $param_value = $options->[0];
    $cmd = sub{
	#--- process it through this guy.  It may change the param value
	&EnterData(0, $param_value, \$param_value);
	if($validation_cmd){
	    unless(&$validation_cmd($param_value)){
		#-- reset the value to whatever the current is
		my ($value) = $pse->added_param($param_name);
		$param_value = $value;
	    }
	}
    };
    my $i = 0;
    my $frame = $hlist -> Frame -> pack;
    
    my $max = 18;
    foreach (@$options){
	$max = length($_) if length($_) > $max;
    }

    #LSF: Let execute it if the validation_cmd is defined.
    if($validation_cmd){
	unless(&$validation_cmd($param_value)){
	    #-- reset the value to whatever the current is
	    my ($value) = $pse->added_param($param_name);
	    $param_value = $value;
	}
    }

    $frame -> BrowseEntry(-label => '', 
			  -width => $max,
			  -variable => \$param_value, 
			  -choices => $options, 
			  -browsecmd => [$cmd]) -> pack(-side => 'top', -anchor => 'e');
    
    $hlist->itemCreate($row, $col, -itemtype => $window_type,-style => $button_style,-widget => $frame);
    
}

#############################
# Add Button to Hlist Entry #
#############################
sub AddButton {
	    
    my ($hlist,$row, $col, $text, $sub_ref, $barcode) = @_;

    my $text_type = 'text';
    #Configure Status button and HList entry
    my $frame = $hlist->Frame->pack(-side => 'top');
    my $button=$frame->Button->pack(-side => 'top');

    $button -> configure(-textvariable => \$text, -height => 2, -width =>8,  -command => [$sub_ref, $barcode, $text]);
    
    #Create window style to place button in
    my $window_type = 'window';
    my $button_style = $hlist->ItemStyle($window_type);
    $hlist->itemCreate($row, $col,-itemtype => $window_type,-style => $button_style,-widget => $frame);
    
    
} #AddEntryMin	

#################################################
# Create special entry to handle input and data #
#################################################
sub AddEntryInputData {
	    
    my ($hlist, $barcode_mgr, $barcode, $barcode_desc, $color) = @_;
    
    # Check Multi Mode Status to Determine if scanning new entry or updating a current entry
    if($barcode_mgr -> MultiMode) {

	my $barcode_ref = $barcode_mgr -> AddBarcode($barcode,$barcode_desc);

	$barcode_mgr -> SetBarcodeInfo('MultiMode', 0);
	
	#Create Minimum entry set
	my $row = &AddEntryMin($hlist, $barcode_ref, $barcode_ref->BarcodeDescription,$color);

	#Configure Input Entry
	my $inputprocess = $barcode_mgr -> InputProcess;
	my $text_type = 'text';
	my $bg_color='red';
	my $rec_style = $hlist->ItemStyle($text_type,-pady => 8, -padx => 1, -bg => $bg_color);
	$hlist->itemCreate($row, 3,-itemtype => $text_type,-style => $rec_style,-text => $inputprocess);
	$::InputRef = $rec_style;
	
	my $window_type = 'window';
	my $button_style = $hlist->ItemStyle($window_type,-pady => 1, -padx => 1);
	
	my $datainfo = $barcode_mgr -> DataInfo;
	
	my $ebuttons;
	my $frame = $hlist -> Frame -> pack;
	foreach my $info (keys %{$datainfo}) {
	    
	    my $data = $datainfo->{$info}->{'Default'};
	    $barcode_ref -> SetData($info, \$data);
	    my $lov = $datainfo -> {$info}->{'ListOfValues'};
	    my $desc = $datainfo -> {$info}->{'Description'};
	    $ebuttons = $frame -> BrowseEntry(-label => $desc, -variable => \$data, -choices => $lov, -browsecmd => [\&EnterData, \$data]) -> pack(-side => 'top');
	}
	$hlist->itemCreate($row, 3,-itemtype => $window_type,-style => $button_style,-widget => $ebuttons);
	
    }
    else {
	my $barcode_ref = $barcode_mgr -> ActiveBarcode;
	$::InputRef -> configure( -bg => 'green');
	$barcode_mgr -> SetBarcodeInfo('MultiMode',1);
	$barcode_ref -> AddInputBarcode($barcode_ref->Barcode);

    }
	
} #AddEntryInputData

#####################################
# Enter Comments via touch Keyboard #
#####################################
sub EnterData {

    my ($brw_ref, $varef, $info, $brwse_cmd) = @_;

    my $comment = $varef;
    
    if(defined $brwse_cmd) {
	&$brwse_cmd($comment);
    }
    if($comment eq 'other') {
	my $comment_win = $::MAIN_WINDOW -> Toplevel(
						     -height =>  $::CANVAS_H,  
						     -width  => $::CANVAS_W
						     );
	
	$comment_win -> geometry($::WIN_GEOMETRY);
	$comment_win -> overrideredirect(1);
	
	
	my $comment_frame =  $comment_win -> Frame (-width => $::CANVAS_W,
						    -height => $::CANVAS_H) -> pack(-side=>'top');
	my $keyboard = $comment_frame -> Keyboard -> pack(-side => 'top');
	
	$comment = $keyboard -> WaitForOk;
	$$info = $comment;
	print "comment = $comment, info = $info\n";

	$comment_win -> destroy;
    }
    elsif($comment eq 'select no grows') {
	$$info = &EnterNoGrows;
    }
    elsif($comment eq 'select fail gel') {
	$$info = &EnterFailedGelLane(96) ;
    }
    elsif($comment =~  /(\d+) lane gel selection/) {
	$$info = &EnterFailedGelLane($1) ;
    }
} #EnterData
	    
#####################################
# Enter Comments via touch Keyboard #
#####################################
sub EnterNoGrows {

    my $map_win = $::MAIN_WINDOW -> Toplevel(
						 -height =>  $::CANVAS_H,  
						 -width  => $::CANVAS_W
						 );
	
    $map_win -> geometry($::WIN_GEOMETRY);
    $map_win -> overrideredirect(1);
	
	
    my $map_frame =  $map_win -> Frame (-width => $::CANVAS_W,
					-height => $::CANVAS_H) -> pack(-side=>'top');
    my $no_selector = $map_frame -> NoGrowSelector -> pack(-side => 'top');
    
    my $no_grows = $no_selector -> WaitForOk;
    
    $map_win -> destroy;

    return $no_grows;
} #EnterNoGrows	    

#########################
# Enter Failed Gel Lane #
#########################

sub EnterFailedGelLane {
    my $num = shift;
    
    my $map_win = $::MAIN_WINDOW -> Toplevel(
						 -height =>  $::CANVAS_H,  
						 -width  => $::CANVAS_W
						 );
	
    $map_win -> geometry($::WIN_GEOMETRY);
    $map_win -> overrideredirect(1);
	
	
    my $map_frame =  $map_win -> Frame (-width => $::CANVAS_W,
					-height => $::CANVAS_H) -> pack(-side=>'top');
    my $no_selector = $map_frame -> VerifyGelLaneSelector(-lanes => $num) -> pack(-side => 'top');
    

    my $failed_gel_lanes = $no_selector -> WaitForOk;
    
    $map_win -> destroy;

    return $failed_gel_lanes;
    
} #EnterFailedGelLane

######################################################################
# Add a Button into a row, col position in an Hlist to enter amounts #
######################################################################
sub AddAmountButton {

    my ($hlist, $row, $col, $atext) = @_;

    #Create window style to place button to enter amount in
    my $window_type = 'window';
    my $button_style = $hlist->ItemStyle($window_type,-pady => 1, -padx => 1);
    $$atext = 1;

    my $frame = $hlist -> Frame -> pack(-side => 'top');
    my $amount_button = $frame -> Button(-textvariable => $atext,
					 -height => 2,
					 -command => sub {&EnterNumber($atext);}) -> pack(-side => 'top');

    $hlist->itemCreate($row, $col,-itemtype => $window_type,-style => $button_style,-widget => $frame);
	
} #AddAmountButton


###################################################
# Toggle the Status of transaction - Pass or Fail #
###################################################
sub StatusControl {

    my ($status_button, $status_text) = @_;

    if($$status_text eq 'fail') {
	$$status_text = 'pass';
	$$status_button -> configure(-bg => 'green');
    }
    else {
	$$status_text = 'fail';
	$$status_button -> configure(-bg => 'red');
    }
 
} #ToggleStatus

####################
# Setup for Keypad #
####################
sub EnterNumber {

    my ($numref) = @_;

    my $num_win = $::MAIN_WINDOW -> Toplevel(
					     -height =>  $::CANVAS_H,  
					     -width  => $::CANVAS_W
					     );
    
    $num_win -> geometry($::WIN_GEOMETRY);
    $num_win -> overrideredirect(1);
    
    
    my $num_frame =  $num_win -> Frame (-width => $::CANVAS_W,
					-height => $::CANVAS_H) -> pack(-side=>'top',
						  #-fill=>'both'
						  );
    
    my $title_frame = $num_frame -> Frame -> pack(qw(-side top));
    
    $title_frame -> Label(-text  => 'Enter Number',
			  -font  => $::medfont
			  ) -> pack(-side=>'top', 
				    -expand=>'yes',
				    );

    # Create Frame for buttons
    my $keypadframe = $num_frame->Frame();
    $keypadframe -> pack(-side => 'top', 
			 -anchor => 'n');
    
    my $keypad = $keypadframe -> Keypad();
    $keypad -> pack(-side => 'top');
    
    my $num = 0;
    
    until($num != 0) {
	$num = $keypad -> WaitForOk;
	$$numref = $num;
	if($num != 0) {
	    $num_win -> destroy;
	}
    }
    
} #EnterNumber

sub UpdateEntryColor {
    
    my ($hlist, $color, $row, $col) = @_;
    my $text_style = $hlist->ItemStyle('text',-pady => 1, -padx => 1, -font => $::medfont);

    $text_style->configure(-bg => $color);

    $hlist->itemConfigure($row, $col, -itemtype => 'text',-style => $text_style);
    
}

sub GetEntryDesc {

    my ($hlist, $row, $col) = @_;

    my $desc = $hlist -> itemCget($row, $col, -text);
    
    return ($desc);
}

1;

#-----------------------------------
# Set emacs perl mode for this file
#
# Local Variables:
# mode:perl
# End:
#
#-----------------------------------

#
# $Header$
#
