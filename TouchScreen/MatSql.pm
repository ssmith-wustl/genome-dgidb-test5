# -*-Perl-*-

##############################################
# Copyright (C) 2000 Craig S. Pohl
# Washington University, St. Louis
# All Rights Reserved.
##############################################

######################################
# TouchScreen Interface Data Manager #
######################################

package TouchScreen::MatSql;

use strict;
use ConvertWell;
use DBI qw(:sql_types);
use DBD::Oracle qw(:ora_types);
use DbAss;
use TouchScreen::CoreSql;

#############################################################
# Production sql code package
#############################################################

require Exporter;


our @ISA = qw (Exporter AutoLoader);
our @EXPORT = qw ( );

my $pkg = __PACKAGE__;

#########################################################

#########################################################
sub new {

    # Input
    my ($class, $dbh, $MainSchema) = @_;
    
    my $self;

    $self = {};
    bless $self, $class;

    $self->{'dbh'} = $dbh;
    $self->{'Schema'} = $MainSchema;
    $self->{'Error'} = '';

    $self->{'CoreSql'} = TouchScreen::CoreSql->new($dbh, $MainSchema);


    return $self;
} #new

###########################
# Commit a DB transaction #
###########################
sub commit {
    my ($self) = @_;
    $self->{'dbh'}->commit;
} #commit

############################
# Destroy a MatSql session #
############################
sub destroy {
    my ($self) = @_;
    undef %{$self}; 
    $self ->  DESTROY;
} #destroy

#########################
# Retrieve CoreSqlError #
#########################
sub GetCoreError {
    my ($self) = @_;
    $self->{'Error'} = $self->{'CoreSql'}->{'Error'};
    return 0;
}



#################################
# Get Barcodes to make reagents #
#################################
sub GetMakeReagentBarcodes {

    my ($self, $barcode, $ps_id) = @_;

    my $dbh = $self -> {'dbh'};
    my $schema = $self -> {'Schema'};

    my $sql = "select rn_reagent_name, batch_number, (CONTAINER_COUNT_STOCK-CONTAINER_USED_STOCK), 
               (CONTAINER_COUNT_AVAILABLE-CONTAINER_USED_AVAILABLE)  from $schema.reagent_informations ri,
               $schema.pse_barcodes pb, $schema.process_step_executions pse
               where pse.pse_id = pb.pse_pse_id and pb.bs_barcode = ri.bs_barcode and 
               pse.ps_ps_id = '$ps_id' and pse.psesta_pse_status = 'inprogress' and pb.bs_barcode = '$barcode'
               and ri.consta_status = 'scheduled' ";

    my $lol = LoLquery($dbh, $sql);
    
    if(defined $lol->[0][0]) {
	my $desc = $lol->[0][0].' batch '.$lol->[0][1].' stock='.$lol->[0][2].' avail='.$lol->[0][3];
	return $desc;
    }

    $self->{'Error'} = "$pkg: GetMakeReagentBarcodes() -> Could not find barcode description for reagent where barcode = $barcode.";

    return 0;

} #GetMakeReagentBarcode

#########################################
# Get available barcodes for qc reagent #
#########################################	
sub GetQcBarcodeDesc {
    my ($self, $barcode, $ps_id) = @_;
    my $dbh = $self -> {'dbh'};
    my $schema = $self -> {'Schema'};

    my $sql = "select rn_reagent_name, batch_number, (CONTAINER_COUNT_STOCK-CONTAINER_USED_STOCK), 
               (CONTAINER_COUNT_AVAILABLE-CONTAINER_USED_AVAILABLE) from $schema.REAGENT_INFORMATIONS 
               where CONSTA_STATUS = 'waiting qc' and bs_barcode = '$barcode'";
    my $lol = LoLquery($dbh, $sql);
 
    if(defined $lol->[0][0]) {
	my $desc = $lol->[0][0].' batch '.$lol->[0][1].' stock='.$lol->[0][2].' avail='.$lol->[0][3];
	return $desc;
    }

    $self->{'Error'} = "$pkg: GetQcBarcodeDesc() -> Could not find barcode description for reagent where barcode = $barcode.";

    return 0;
    

} #GetQcBarcodes

sub GetAdd2AvailBarcodeDesc {
    my ($self, $barcode, $ps_id) = @_;
    my $dbh = $self -> {'dbh'};
    my $schema = $self -> {'Schema'};

    my $sql = "select rn_reagent_name, batch_number, (CONTAINER_COUNT_STOCK-CONTAINER_USED_STOCK), 
               (CONTAINER_COUNT_AVAILABLE-CONTAINER_USED_AVAILABLE) from $schema.REAGENT_INFORMATIONS 
               where CONSTA_STATUS = 'available' and ((CONTAINER_COUNT_STOCK - CONTAINER_USED_STOCK) > 0) 
               and bs_barcode = '$barcode'";
    my $lol = LoLquery($dbh, $sql);
 
    if(defined $lol->[0][0]) {
	my $desc = $lol->[0][0].' batch '.$lol->[0][1].' stock='.$lol->[0][2].' avail='.$lol->[0][3];
	return $desc;
    }

    $self->{'Error'} = "$pkg: GetAdd2AvailBarcodeDesc() -> Could not find barcode description for reagent where barcode = $barcode.";

    return 0;
}


sub GetReagentCheckoutBarcodeDesc {

    my ($self, $barcode, $ps_id) = @_;
    my $dbh = $self -> {'dbh'};
    my $schema = $self -> {'Schema'};
    
    my $sql = "select rn_reagent_name, batch_number, (CONTAINER_COUNT_STOCK-CONTAINER_USED_STOCK), 
               (CONTAINER_COUNT_AVAILABLE-CONTAINER_USED_AVAILABLE) from $schema.REAGENT_INFORMATIONS 
               where CONSTA_STATUS = 'available' and ((CONTAINER_COUNT_AVAILABLE - CONTAINER_USED_AVAILABLE) > 0)
               and bs_barcode = '$barcode'";
    my $lol = LoLquery($dbh, $sql);
    
    if(defined $lol->[0][0]) {
	foreach my $ln (@$lol) {
	    foreach my $ps (@$ln) {
		$ps = 0 if(!defined $ps);
	    }
	}

	my $desc = $lol->[0][0].' batch '.$lol->[0][1].' stock='.$lol->[0][2].' avail='.$lol->[0][3];
	return $desc;
    }
    else {
	$sql = "select rn_reagent_name, batch_number, CONTAINER_COUNT_AVAILABLE, CONTAINER_USED_AVAILABLE, CONSTA_STATUS
	        from $schema.REAGENT_INFORMATIONS where bs_barcode = '$barcode'";
	$lol = LoLquery($dbh, $sql);
	if(defined $lol->[0][0]) {
	    my $amount = $lol->[0][2] - $lol->[0][3];

	    $self->{'Error'} = 'Not Available for checkout!! '.$lol->[0][0].' batch '.$lol->[0][1].' Available = '.$amount.'  Status = '.$lol->[0][4]; 
	}
	else {
	    $self->{'Error'} = "$pkg: GetReagentCheckoutBarcodeDesc() -> Could not find barcode description for reagent where barcode = $barcode.";
	}
    }
    return 0;

}


sub RetireChemBarcodeDesc {

    my ($self, $barcode, $ps_id) = @_;
    my $dbh = $self -> {'dbh'};
    my $schema = $self -> {'Schema'};

    my $sql = "select  cn_chemical_name, lot_number, (CONTAINER_COUNT-CONTAINER_USED) from $schema.CHEMICAL_INFORMATIONS 
               where CONSTA_STATUS = 'available' and ((CONTAINER_COUNT - CONTAINER_USED) > 0)
               and bs_barcode = '$barcode'";
    my $chem = LoLquery($dbh, $sql);
 
    if(defined $chem->[0][0]) {
	my $desc = $chem->[0][0].' lot '.$chem->[0][1].' stock='.$chem->[0][2];
	return $desc;
    }

    $self->{'Error'} = "$pkg: RetireChemBarcodeDesc() -> Could not find barcode description for chemical where barcode = $barcode.";
    
    return 0;
} #RetireChemBarcodeDesc


##################################################
# Returns a Chemical name for a chemical barcode #
##################################################
sub GetChemName {

    my ($self, $barcode) = @_;
    my $dbh = $self -> {'dbh'};
    my $schema = $self -> {'Schema'};
	
    my $sql = "select cn_chemical_name from $schema.chemical_informations where bs_barcode = '$barcode' and consta_status = 'available'";
    my $chem = Query($dbh, $sql);
 
    if(defined $chem) {
	return $chem;
    }
    
    $self->{'Error'} = "$pkg: GetChemName() -> Could not find chemical name where barcode = $barcode.";
    return 0;
    

    
} #GetChemDesc




################################################
# Update the Chemical and Reagent tables in DB #
################################################
sub MakeReagent {
   
    my ($self, $ps_id, $bar_in, $bar_out, $emp_id, $options, $pre_pse_ids) = @_;
  
    my $dbh = $self -> {'dbh'};
    my $schema = $self -> {'Schema'};
    my $status = 'completed';
    
    # Get Pse linked with scheduled making of the reagent
    my $sql = "select PSE_PSE_ID from $schema.REAGENT_INFORMATIONS where BS_BARCODE = '$bar_in->[0]'";
    my $pse_id = Query($dbh, $sql);
    if($pse_id) {
	
	if ($status eq 'failed') {
	    $sql = "update $schema.REAGENT_INFORMATIONS set CONSTA_STATUS  = 'failed making' where BS_BARCODE = '$bar_in->[0]'";
	}
	else {
	    
	    $sql = "select QC_STATUS from $schema.REAGENT_NAMES 
                    where REAGENT_NAME = (select RN_REAGENT_NAME from REAGENT_INFORMATIONS where BS_BARCODE = '$bar_in->[0]')";
	    
	    my $qc_status = Query($dbh, $sql);
	 
	    if($qc_status) {
		
		my $next_status;
		if($qc_status eq 'yes') {
		    $next_status = 'waiting qc';
		}
		else {
		    $next_status = 'available';
		}
		
		$sql = "update $schema.REAGENT_INFORMATIONS set CONSTA_STATUS  = '$next_status' where BS_BARCODE = '$bar_in->[0]'";
		
		my $result = Insert($dbh, $sql);
		
		if($result) {
		    
		    # insert into process step executions
		    $sql = "update $schema.process_step_executions 
                            set PSE_SESSION = '0', DATE_COMPLETED = sysdate, PSESTA_PSE_STATUS = '$status',
                            pr_pse_result = 'successful', EI_EI_ID_CONFIRM = '$emp_id' where pse_id = '$pse_id'";
		    $result = Insert($dbh, $sql);
		    
		    if($result) {
			
			foreach my $barout (@{$bar_out}) {
			    $sql = "insert into  $schema.CHEMICAL_REAGENT_INFOS (RI_BS_BARCODE, CI_BS_BARCODE) values ('$bar_in->[0]', '$barout')";    
			    $result = Insert($dbh, $sql);
		    
			    if($result) {
				$sql = "insert into $schema.pse_barcodes (bs_barcode, pse_pse_id, direction, psebar_id) 
                                        values ('$barout', '$pse_id', 'in', psebar_seq.nextval)";
				$result = Insert($dbh, $sql);
				
				if(!$result) {

				    $self->{'Error'} = "$pkg: MakeReagent() -> Could not insert into pse_barcodes where barcode = $barout, pse_id = $pse_id, direction = in.";
				    

				    last;
				}
			    }
			    else {
				$self->{'Error'} = "$pkg: MakeReagent() -> Could not insert into CHEMICAL_REAGENT_INFOS  reagent = $bar_in and chemical = $barout.";
				last;
			    }
			    
			}
			$self->commit;
			return [$pse_id];
		    }
		    else {
			$self->{'Error'} = "$pkg: MakeReagent() -> Could not update process_step_executions.";
		    }
		}
		else {
		    $self->{'Error'} = "$pkg: MakeReagent() -> Could not update reagent container status.";
		}
	    }
	    else {
		$self->{'Error'} = "$pkg: MakeReagent() -> Could not get reagent container status.";
	    }
	}
    }
    else {
	$self->{'Error'} = "$pkg: MakeReagent() -> Could not get pse_id for reagent = $bar_in.";
    }
    return 0;
} #MakeReagent

############################################
# Update the result of the Qc of a Reagent #
############################################
sub QcReagent {

    my ($self, $ps_id, $bar_in, $bar_out, $emp_id, $options, $pre_pse_ids) = @_;
  
    my $dbh = $self -> {'dbh'};
    my $schema = $self -> {'Schema'};
    my $session;
    my $sql;
    my $pse_ids = [];
    my $status = 'completed';
    
    if ( $status eq 'failed' ) {
    	$session = 1;
    	$sql = "update $schema.REAGENT_INFORMATIONS set CONSTA_STATUS  = 'failed qc' where BS_BARCODE = '$bar_in->[0]'";
    }
    else {
	$session = 0;
    	$sql = "update $schema.REAGENT_INFORMATIONS set CONSTA_STATUS  = 'available' where BS_BARCODE = '$bar_in->[0]'";
    }

    my $result = Insert($dbh, $sql);
       
    if($result) {

	#LSF: Find the pre_pse_ids if it is undef.
        $pre_pse_ids = $self->_fix_the_empty_prior_pse_ids($pre_pse_ids, $bar_in);
	my $new_pse_id = $self -> {'CoreSql'} -> BarcodeProcessEvent($ps_id, $bar_in->[0], undef, $status, 'successful', $emp_id, undef, $pre_pse_ids->[0]);
	return 0 if($new_pse_id == 0);

	push(@{$pse_ids}, $new_pse_id);
	return $pse_ids;
    }
    else {
	$self->{'Error'} = "$pkg: QcReagent() -> Could not update reagent container status.";
	    
    }

    return(0);
} #QcReagent





#####################################################
# Adds Reagent Chemicals to the Available Inventory #
#####################################################
sub AddToAvailable {

    my ($self, $ps_id, $bar_in, $bar_out, $emp_id, $options, $pre_pse_ids) = @_;
  
    my $dbh = $self -> {'dbh'};
    my $schema = $self -> {'Schema'};
    my $session = 0;
    my $status = 'completed';
    my $pse_ids = [];

    #LSF: Find the pre_pse_ids if it is undef.
    $pre_pse_ids = $self->_fix_the_empty_prior_pse_ids($pre_pse_ids, $bar_in);
    my $new_pse_id = $self -> {'CoreSql'} -> BarcodeProcessEvent($ps_id, $bar_in->[0], undef, $status, 'successful', $emp_id, undef, $pre_pse_ids->[0]);
    if (!$new_pse_id) {
	return 0;
    }
    push(@{$pse_ids}, $new_pse_id);
    

    return $pse_ids;
} #AddToAvailable



#####################################################
# Adds Reagent Chemicals to the Available Inventory #
#####################################################
sub AddToAvailAmount {

    my ($self, $bar_in, $amount) = @_;
  
    my $dbh = $self -> {'dbh'};
    my $schema = $self -> {'Schema'};
    
    my $sql = "select CONTAINER_USED_STOCK, CONTAINER_COUNT_AVAILABLE, CONTAINER_COUNT_STOCK 
               from $schema.REAGENT_INFORMATIONS where BS_BARCODE = '$bar_in'";
    
    my $line = LoLquery($dbh, $sql);

    my $cu_stock = $line->[0][0];
    my $cc_stock = $line->[0][2];
    my $cc_avail = $line->[0][1];
	

    if (($cu_stock+$amount) <= $cc_stock) {
	$cc_avail = $amount + $cc_avail;
	$cu_stock = $amount + $cu_stock;
    }
    else {
	
	$self->{'Error'} = "Could not add amount = $amount to count avail = $cc_avail and used stock = $cu_stock.";
	return 0;
    }

    $sql = "update $schema.REAGENT_INFORMATIONS 
            set CONTAINER_USED_STOCK = '$cu_stock', CONTAINER_COUNT_AVAILABLE = '$cc_avail' where BS_BARCODE = '$bar_in'";
    my $result = Insert($dbh, $sql);
    
    if(!$result) {
	$self->{'Error'} = "$pkg: AddToAvailAmount() -> Could not update reagent = $bar_in container count avail = $cc_avail and used stock = $cu_stock.";
	return 0;
    }

    return 1;

} #AddToAvailAmount


#############################
# CheckOut Reagents from DB #
#############################
sub ReagentCheckout {

    my ($self, $ps_id, $bar_in, $bar_out, $emp_id, $options, $pre_pse_ids) = @_;
  
    my $dbh = $self -> {'dbh'};
    my $schema = $self -> {'Schema'};
    my $session = 0;
    my $status = 'completed';
    my $pse_ids = [];
    #LSF: Find the pre_pse_ids if it is undef.
    $pre_pse_ids = $self->_fix_the_empty_prior_pse_ids($pre_pse_ids, $bar_in);
        
    my $new_pse_id = $self -> {'CoreSql'} -> BarcodeProcessEvent($ps_id, $bar_in->[0], undef, $status, 'successful', $emp_id, undef, $pre_pse_ids->[0]);
    if (!$new_pse_id) {
	return 0;
    }
    push(@{$pse_ids}, $new_pse_id);
    
    return $pse_ids;
 
} #ReagentCheckout

sub _fix_the_empty_prior_pse_ids {
  my $self = shift;
  my $pre_pse_ids = shift;
  my $bar_in = shift;
  unless($pre_pse_ids && scalar(@$pre_pse_ids) > 0) {
    $pre_pse_ids  = [map { $_->pse_id } GSC::PSEBarcode->get(barcode => $bar_in->[0], direction => 'out')];      
    unless(@{$pre_pse_ids}) {
      $pre_pse_ids = [0];
    }
  }
  return $pre_pse_ids;
}
#############################
# CheckOut Reagents from DB #
#############################
sub ReagentCheckoutAmount {

    my ($self, $bar_in, $amount) = @_;
  
    my $dbh = $self -> {'dbh'};
    my $schema = $self -> {'Schema'};
    
    my $sql = "select CONTAINER_USED_AVAILABLE, CONTAINER_COUNT_AVAILABLE, CONTAINER_USED_STOCK, CONTAINER_COUNT_STOCK 
               from $schema.REAGENT_INFORMATIONS where BS_BARCODE = '$bar_in'";
    
    my $lol = LoLquery($dbh, $sql);
   
    my $cu_avail = $lol->[0][0];
    my $cc_avail = $lol->[0][1];
    my $cu_stock = $lol->[0][2];
    my $cc_stock = $lol->[0][3];

    if($cu_avail < $cc_avail) {
	$cu_avail =  $cu_avail + $amount;
    }
    

    $sql = "update $schema.REAGENT_INFORMATIONS set CONTAINER_USED_AVAILABLE = '$cu_avail' where BS_BARCODE = '$bar_in'";
    my $result = Insert($dbh, $sql);
    
    if(!$result) {
	$self->{'Error'} = "$pkg: ReagentCheckoutAmount() -> Could not update reagent = $bar_in container count avail = $cc_avail.";
	return 0;
    }   
	
    if(($cu_avail >= $cc_avail)&&($cu_stock >= $cc_stock)) {
	
	
	$sql = "update $schema.REAGENT_INFORMATIONS set CONSTA_STATUS = 'depleted' where BS_BARCODE = '$bar_in'";
	my $result = Insert($dbh, $sql);
    
	if(!$result) {
	    $self->{'Error'} = "$pkg: ReagentCheckoutAmount() -> Could not update reagent = $bar_in status to depleted.";
	    return 0;
	}
    }

    return 1;
} #ReagentCheckoutAmount


###########################################
# Retire a chemical container from the DB #
###########################################
sub RetireChemicalContainer {
    
    my ($self, $ps_id, $bar_in, $bar_out, $emp_id, $options, $pre_pse_ids) = @_;
  
    my $dbh = $self -> {'dbh'};
    my $schema = $self -> {'Schema'};
    my $session = 0;
    my $status = 'completed';
    my $pse_ids = [];

    #LSF: Find the pre_pse_ids if it is undef.
    $pre_pse_ids = $self->_fix_the_empty_prior_pse_ids($pre_pse_ids, $bar_in);
    my $new_pse_id = $self -> {'CoreSql'} -> BarcodeProcessEvent($ps_id, $bar_in->[0], undef, $status, 'successful', $emp_id, undef, $pre_pse_ids->[0]);
    if (!$new_pse_id) {
	return 0;
    }
    push(@{$pse_ids}, $new_pse_id);
    
    return $pse_ids;
 
} #RetireChemicalContainer

###########################################
# Retire a chemical container from the DB #
###########################################
sub RetireChemicalContainerAmount {
    
    my ($self, $bar_in, $amount) = @_;
  
    my $dbh = $self -> {'dbh'};
    my $schema = $self -> {'Schema'};
    
    my $sql = "select CONTAINER_USED from $schema.CHEMICAL_INFORMATIONS where BS_BARCODE = '$bar_in'";
    
    my $cused = Query($dbh, $sql);

    $cused = $cused + $amount;

    $sql = "update $schema.CHEMICAL_INFORMATIONS set CONTAINER_USED = '$cused' where BS_BARCODE = '$bar_in'";
    my $result = Insert($dbh, $sql);
    
    if(!$result) {
	$self->{'Error'} = "$pkg: RetireChemicalContainerAmount() -> Could not update chemical = $bar_in container used = $cused.";
	return 0;
    }

    return 1;
} #RetireChemicalContainerAmount

#####################################################
# Returns a list of chemicals for a Reagent Barcode #
#####################################################
sub GetChemicalsForReagent {
    my ($self, $barcode) = @_;

    my $dbh = $self -> {'dbh'};
    my $schema = $self -> {'Schema'};

    my $sql = "select rn_reagent_name from $schema.reagent_informations where bs_barcode = '$barcode'";
    my $reagent =  Query($dbh, $sql);
    if(defined $reagent) {

	$sql = "select CN_CHEMICAL_NAME from $schema.RECIPES where RN_REAGENT_NAME = '$reagent'";
	my $chemical_ref = Lquery($dbh, $sql);
	
	if(defined $chemical_ref->[0]) {
	    my $lov;
	    foreach my $chem ( @{$chemical_ref} ) {
		if($chem ne 'Deionized Water') {
		    push(@{$lov}, $chem);
		}
	    }
	    return $lov
	}
	else {
	    $self->{'Error'} = "$pkg: GetChemicalsForReagent() -> Could not find chemicals in Recipe Table for reagent = $reagent.";
	}
    }
    else {
	$self->{'Error'} = "$pkg: GetChemicalsForReagent() -> Could not find reagent name where barcode = $barcode.";
    }
    return 0;
    
} #GetChemicalsForReagent

###########################
# Display Recipe selected #
########################### 
sub DisplayRecipe {

    my ($self, $window, $barcode) = @_;
    

    my $rec_win = $window -> Toplevel(
				      -height =>  $::CANVAS_H,  
				      -width  => $::CANVAS_W
				      );
    
    $rec_win -> geometry($::WIN_GEOMETRY);

    $rec_win -> overrideredirect(1);
    
    
    my $rec_frame =  $rec_win -> Frame (-width => $::CANVAS_W,
					-height => $::CANVAS_H) -> pack(-side=>'top',
						  );
    
    my $title_frame = $rec_frame -> Frame -> pack(qw(-side top));
    
    $title_frame -> Label(-text  => 'RECIPE',
			  -font  => $::bigfont
			  ) -> pack(-side=>'top', 
				    -expand=>'yes',
				    );
    
    my $recipe = $self -> GetRecipe($barcode);

    my $recipe_frame = $rec_frame -> Frame(-relief => 'sunken') -> pack(-side => 'top',
									#-fill => 'both'
									);
    my $recipe_text = $recipe_frame -> Text() -> pack(-side=>'left');
    $recipe_text -> insert('end', $recipe);    
    
    my $button_frame = $rec_frame -> Frame -> pack(-side => 'top');
    my $cbframe = $button_frame -> Frame -> pack(-side => 'left');
    my $pbframe = $button_frame -> Frame -> pack(-side => 'right');
    
    my $close_bttn = $cbframe -> Button(-text => 'Close',
					-command => sub{$rec_win -> destroy;}) -> pack(-side => 'top',
										       -padx => 30);
    my $print_bttn = $pbframe -> Button(-text => 'Print',
					-command => sub{&PrintText($recipe);
							$rec_win -> destroy;}) -> pack(-side => 'top',
										       -padx => 30);


} #DisplayRecipe

#########################
# Prints text passed in #
#########################
sub PrintText {
    
    my ($text) = @_;
    my $file = '/tmp/printfile';

    `rm $file` if(-e $file);
    `echo '$text' > $file`;
    `enscript --ps-level=1 --word-wrap $file`;


} #PrintText

########################################
# Returns the instruction for a recipe #
########################################
sub GetRecipe {

    my ($self,$barcode) = @_;
    
    my $dbh = $self -> {'dbh'};
    my $schema = $self -> {'Schema'};
    
    my $sql = "select RN_REAGENT_NAME from $schema.REAGENT_INFORMATIONS where BS_BARCODE = '$barcode'";
    my $reagent = Query($dbh, $sql);
    
    $sql = "select INSTRUCTIONS from $schema.REAGENT_NAMES where REAGENT_NAME = '$reagent'";
    my $instructions = Query($dbh, $sql);
    
    $sql = "select CN_CHEMICAL_NAME, QUANITY, CU_UNIT from $schema.RECIPES where RN_REAGENT_NAME = '$reagent'";
    my $recipe_inputs = LoLquery($dbh, $sql);
    $sql = "select CONTAINER_COUNT, CONTAINER_SIZE, CU_UNIT from $schema.REAGENT_NAMES where REAGENT_NAME = '$reagent'";
    
    my $recipe_outputs = LoLquery($dbh, $sql);

    if((defined $recipe_inputs)&&(defined $recipe_outputs->[0])) {
	my ($count, $size, $unit) = ('','','');
	$count = $recipe_outputs->[0][0];
	$size  = $recipe_outputs->[0][1];
	$unit = $recipe_outputs->[0][2];
	
	my $recipe = "\n$reagent - makes $count, $size $unit containers.\n\n";
	
	$recipe = $recipe."Ingredients:\n";
	my $format = ("\t\t@<<<<<<<<<<<<<<<<<<<<<<<<<<<\t@<<<<<\t@<<<<<<<<\n");
	foreach my $row (@{$recipe_inputs}) {
	    my @recipe;
	    push(@recipe, $row->[0]);
	    push(@recipe, $row->[1]);
	    push(@recipe, $row->[2]);
	    
	    formline($format, @recipe);
	    my $linetoprint = "$^A";
	    $^A = '';
	    
	    $recipe = $recipe.$linetoprint;
	}
	
	$recipe = $recipe."\n\nInstructions:\n";
	$recipe = $recipe."$instructions" if(defined $instructions);
	return ($recipe);
    }

} #GetRecipe



1;

#-----------------------------------
# Set emacs perl mode for this file
#
# Local Variables:
# mode:perl
# End:
#
#-----------------------------------
