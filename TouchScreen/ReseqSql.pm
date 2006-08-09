# -*-Perl-*-

##############################################
# Copyright (C) 2003 Craig S. Pohl
# WASHINGTON University, St. Louis
# All Rights Reserved.
##############################################

package TouchScreen::ReseqSql;

use strict;
use ConvertWell ':all';


#############################################################
# Production sql code package
#############################################################

require Exporter;

our @ISA = qw (Exporter AutoLoader TouchScreen::CoreSql);
our @EXPORT = qw ( );

my $pkg = __PACKAGE__;

#########################################################
# Create a new instance of the ReseqSql code so that you #
# can easily use more than one data base schema         #
#########################################################
sub new {

    # Input
    my ($class, $dbh, $schema) = @_;
    
    my $self;

    $self = {};
    bless $self, $class;

    $self->{'dbh'} = $dbh;
    $self->{'Schema'} = $schema;
    $self->{'Error'} = '';
    
    $self = $class->SUPER::new( $dbh, $schema);
    $self -> {'ScanSeqInputPlate'} = 'dna';
    $self -> {'PCROutputDualPrimer'} = 1;

    $self-> {'CheckLoadStatus'} = $dbh->prepare(qq/select count(pse_id) from pse_barcodes, process_step_executions, process_steps
						where 
						ps_id = ps_ps_id and
						pse_id = pse_pse_id and
						pro_process_to = 'check gel' and
						direction = 'in' and
						psesta_pse_status = 'completed' and
						bs_barcode in (
							       select pb2.bs_barcode from pse_barcodes pb1, pse_barcodes pb2, process_step_executions, process_steps
							       where 
							       ps_id = ps_ps_id and
							       pse_id = pb1.pse_pse_id and
							       pse_id = pb2.pse_pse_id and
							       pro_process_to = 'load gel' and
							       pb2.direction = 'out' and
							       pb1.direction = 'in' and
							       psesta_pse_status = 'completed' and
							       pb1.bs_barcode = ?
							       )	and
						pr_pse_result = ? 
						/);
    

    $self -> {'GetPcrOnGel'} = "select distinct pcr.* from pcr_product pcr, dna_pse pp where 
	pcr.pcr_id = pp.dba_id and pp.pse_id = ?";
    
    
    $self -> {'CountPseFromBarcode'} = $dbh -> prepare(qq/select count(dp.pse_id)
						       from pse_barcodes pb, dna_pse dp
						       where pb.pse_pse_id = dp.pse_id and
						       pb.bs_barcode = ? and
						       pb.direction = ? /);
    
    
    $self->{'GetPrimerFromBarcode'} = "select distinct p.* 
	from primers p, custom_primer_pse cp, pse_barcodes pb
	where 
	p.pri_id = cp.pri_pri_id 
	and pb.pse_pse_id = cp.pse_pse_id 
	and bs_barcode = ? and pb.direction = 'out'";
    
    
     
    
    
    $self -> {'GetPcrIdPlIdFromPcrBarRow'} = $dbh -> prepare(qq/select distinct pp.pcr_id, dl.location_name, dl.dl_id, pp.pcr_name  
							     from pse_barcodes pbx, dna_pse dp, dna_location dl, pcr_product pp, process_step_executions pse,
							     process_steps p
							     where pbx.bs_barcode = ? 
							     and pp.pcr_id = dp.dna_id 
							     and dl.dl_id = dp.dl_id 
							     and pbx.pse_pse_id = dp.pse_id 
							     and pse.pse_id = dp.pse_id 
							     and pse.ps_ps_id = p.ps_id 
							     and pro_process_to = 'create pcr fragment'
							     and location_name like ? 
							     order by dl.dl_id/);
    
    $self -> {'Get384wellCleanupPse'} = $dbh -> prepare( qq/select distinct pse.pse_id 
							 from process_step_executions pse, dna_pse dp
							 where 
							 pse.pse_id = dp.pse_id and
							 pse.psesta_pse_status = 'inprogress' and
							 dp.dna_id in (select dna_id from dna_pse where pse_id = ?)/);
    




    $self -> {'GetDNAPSEFromDNAandPSE'} = "select dp.* from dna_pse dp, pse_barcodes pb
	where
	dp.pse_id = pb.pse_pse_id 
	and direction = 'out' 
	and dp.dna_id = ?
	and bs_barcode in (select bs_barcode from pse_barcodes pb where 
			   pb.pse_pse_id = ? and
			   direction = 'in')";
    
    
    
    $self -> {'NumberOfTimesLoaded'} = $dbh -> prepare(qq/select count(pse.pse_id) from pse_barcodes pb, process_step_executions pse
						       where 
						       pse.pse_id = pb.pse_pse_id 
						       and direction = 'in'and 
						       (bs_barcode, ps_ps_id) in  (select pb.bs_barcode, ps_ps_id from pse_barcodes pb, process_step_executions pse
										   where 
										   pse.pse_id = pb.pse_pse_id 
										   and pb.pse_pse_id = ?
										   and direction = 'in')/);
    




    
    
    $self -> {'GetPrimerIdFromBarcodeAndLocation'} = "select pp.* from pse_barcodes pb, custom_primer_pse cpp, primers pp
	where 
	cpp.pri_pri_id = pp.pri_id and
	pb.pse_pse_id = cpp.pse_pse_id and
	cpp.dl_id = ? and
	pb.bs_barcode = ? and
          direction = 'out'
        order by pp.pd_primer_direction
        ";
    



 
    
    return $self;
} #new

###########################
# Commit a DB transaction #
###########################
sub commit {
    my ($self) = @_;
    $self->{'dbh'}->commit;
} #commit

###########################
# Commit a DB transaction #
###########################
sub rollback {
    my ($self) = @_;
    $self->{'dbh'}->rollback;
} #commit

#############################
# Destroy a PrefinishSql session #
#############################
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

################################################################################
#                                                                              #
#                               Input verification subroutines                 #
#                                                                              #
################################################################################


sub GetAvailRearrayPlates {

    my ($self, $barcode, $ps_id) = @_;

    return ($barcode, []) if($barcode eq 'empty');
    my ($result, $pses) = $self -> GetAvailBarcodeInInprogress($barcode, $ps_id);

    if($result) {

	$self -> {'CheckLoadStatus'} -> execute($barcode, 'successful');
	my ($suc_count) = $self-> {'CheckLoadStatus'} -> fetchrow_array;
	if(!$suc_count) {
	    $self->{'Error'} = "$pkg: RearrayPcrPlates() -> Barcode $barcode does not have a successful gel check step.";
	    return 0;
	}
    }
    
    return ($result, $pses);
}


sub GetAvailSeqInputs {

    my ($self, $barcode, $ps_id) = @_;

    my $dbh = $self->{'dbh'};
    if($barcode eq 'empty') {
      if($self->{'ScanSeqInputPlate'} eq "forward") {
	  $self->{'ScanSeqInputPlate'} = "reverse" ;
      } elsif ($self->{'ScanSeqInputPlate'} eq "reverse" ) {
	  $self->{'ScanSeqInputPlate'} = "dna";
      }
      return ($barcode, []) ;
    }
    if(($barcode =~ /^(2c)|(2b)/) && ($self -> {'ScanSeqInputPlate'} eq 'dna')) {

	my ($result, $pses) = $self -> GetAvailBarcodeInInprogress($barcode, $ps_id);
	
	if($result) {
	    $self -> {'ScanSeqInputPlate'} = 'forward';
	}
    
	return($result, $pses);
    }
    elsif(($barcode =~ /^21/) && ( $self->{'ScanSeqInputPlate'} =~ /(forward)|(reverse)/))  {
	
	#Check For Forward Primer Plate
	my @primer_obj = GSC::Primer->load(sql => [$self->{'GetPrimerFromBarcode'}, $barcode]);
	
	my @primers; 
	foreach my $primer (@primer_obj) {
	    
	    if(($primer->primer_direction ne $self->{'ScanSeqInputPlate'}) && ($primer->primer_name ne '-21UPpOT')) {

		my ($rearray) = App::DB::dbh->selectrow_array(qq/select count(*) 
							      from pse_barcodes pb, process_step_executions pse, process_steps ps
							      where 
							      pb.pse_pse_id = pse.pse_id and
							      pse.ps_ps_id= ps.ps_id and
							      pb.bs_barcode = '2101hO' and
							      pb.direction = 'out' and
							      ps.pro_process_to = 'rearray oligo'/);

		#don't fail the rearray seq primers, they could have forward and rev in same plate
		if($rearray == 0) {
		    
		    $self->{'Error'}="Not a valid primer barcode.";
		    return(0);
		}
	    }
	    push(@primers, $primer->primer_name);
	}


	if($self->{'ScanSeqInputPlate'} eq "forward") {
	    $self->{'ScanSeqInputPlate'} = "reverse" ;
	} elsif ($self->{'ScanSeqInputPlate'} eq "reverse" ) {
	    $self->{'ScanSeqInputPlate'} = "dna";
	}
	my %hash;
	map($hash{$_} = 1, @primers);


	return(join(' ', keys %hash));

    }


    $self -> {'Error'} = "$pkg: GetAvailSeqInputs() -> Not a valid plate type, expecting $self->{'ScanSeqInputPlate'}.";
   
    return 0;
}       


################################################################################
#                                                                              #
#                                            Input Defining Subroutines        #
#                                                                              #
################################################################################

sub GetPcrPlatesOnGel {

    my ($self, $barcode, $pse) = @_;


    my @pcr_obj = GSC::PCRProduct->load(sql => [$self -> {'GetPcrOnGel'}, $pse]);

    unless(@pcr_obj) {
	$self->{'Error'} = "$pkg: GetPcrPlatesOnGel() -> Failed finding gel information for $barcode, $pse.";
	return 0;
    }
    
    my $desc  = substr($pcr_obj[0]->pcr_name, 0, 5).'  '.substr($pcr_obj[0]->pcr_name, 8, length($pcr_obj[0]->pcr_name));

    return ($desc);
    

}


################################################################################
#                                                                              #
#                                           Output Defining Subroutines        #
#                                                                              #
################################################################################

sub PCRFragmentOptions {
    
    my ($self) = @_;

    my @ret_array=();
    for my $i (1..4) {
	push @ret_array, "#$i Primer 1";
	push @ret_array, "#$i Primer 2";
	push @ret_array, "#$i Destination Plate";
	
    }

    $self -> {'PCROutputDualPrimer'} = 1;
    return(\@ret_array);
} # PCRFragmentOptions

sub PCRFragmentRearrayOptions {
    
    my ($self) = @_;
    my @ret_array;

    for my $i (1..12) {
	push @ret_array, ("#$i Primer Plate", "#$i Destination Plate");
    }
    
    $self -> {'PCROutputDualPrimer'} = 0;
    
    return(\@ret_array);
} # PCRFragmentOptions




################################################################################
#                                                                              #
#                              Output verification subroutines                 #
#                                                                              #
################################################################################


sub CheckIfUsedAsOutputFor384 {

    my ($self, $barcode) = @_;

    my $desc = $self -> CheckIfUsed($barcode, 'out');
    #LSF: Comment out this to do the check.  It does't give the error.

    $self -> {'CountPseFromBarcode'} -> execute($barcode, 'out');
    my $r = $self -> {'CountPseFromBarcode'} -> fetchall_arrayref;
    return ($self->{'Error'}) if($r->[0][0] > 190); #192 wells for frw/rev -2 control wells

    $self->{__IS_EMPTY__} = $desc ? 1 : 0;

    my $bar_obj = GSC::Barcode->get(barcode => $barcode);
    
    return $bar_obj->barcode_description.($self->{__IS_EMPTY__} ? '' : ' partially filled');

} #CheckIfUsedAsOutput


sub CheckIfCorrectPCROutput {
    my ($self, $barcode)=@_;

    if($self->{'CurrentPcrOutputPhase'}==0) {
	if($self -> {'PCROutputDualPrimer'} == 1) {
	    #Check For Forward Primer Plate
	    my @primer_obj = GSC::Primer->load(sql => [$self->{'GetPrimerFromBarcode'}, $barcode]);
	    
	    my @primers; 
	    foreach my $primer (@primer_obj) {
		
		if($primer->primer_direction ne 'forward') {
		    $self->{'Error'}="Not a valid forward primer barcode.";
		    return(0);
		}
		
		push(@primers, $primer->primer_name);
	    }
	    
	    my %hash;
	    map($hash{$_} = 1, @primers);
	    
	    $self->{'CurrentPcrOutputPhase'}=1;
	    return(join(' ', keys %hash));
	}
	else {
	    #Check For Forward Primer Plate
	    my @primer_obj = GSC::Primer->load(sql => [$self->{'GetPrimerFromBarcode'}, $barcode]);
	    
	    my @primers; 
	    foreach my $primer (@primer_obj) {
		push(@primers, $primer->primer_name);
	    }
	    
	    my %hash;
	    map($hash{$_} = 1, @primers);
	    
	    $self->{'CurrentPcrOutputPhase'}=2;
	    return(join(' ', keys %hash));

	}
    } elsif($self->{'CurrentPcrOutputPhase'}==1) {
	#Check For Reverse Primer Plate
	my @primer_obj = GSC::Primer->load(sql => [$self->{'GetPrimerFromBarcode'}, $barcode]);
	
	my @primers; 
	foreach my $primer (@primer_obj) {

	    if($primer->primer_direction ne 'reverse') {
		$self->{'Error'}="Not a valid forward primer barcode.";
		return(0);
	    }
	    
	    push(@primers, $primer->primer_name);
	}

	my %hash;
	map($hash{$_} = 1, @primers);

	$self->{'CurrentPcrOutputPhase'}=2;



	return(join(' ', keys %hash));

    } elsif($self->{'CurrentPcrOutputPhase'}==2) {
	my $desc = $self->CheckIfUsed($barcode, 'out');
	if(!$desc) {
	    $self->{'Error'}="Not a valid output plate";
	    return (0); 
	}
	$self->{'CurrentPcrOutputPhase'}=0;
	return $desc;
    } 
    
    $self->{'Error'}="$pkg:  CheckIfCorrectPCROutput() -> Invlaid Current PCR Output Phase:  ".$self->{'CurrentPcrOutputPhase'}.".";
    return 0;
} #CheckIfCorrectPCROutput



############################################################################################
#                                                                                          #
#                         Confirm Subrotine Processes                                      #
#                                                                                          #
############################################################################################


# The point of this rearray step is to take a 96 well plate with 24 samples in it and
# rearray that to fill a 96 well plate
sub CreateRearrayPlate {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
    
    my $pses = [];
    my $pse = $self -> ProcessOneInputToOneOutput($ps_id, $bars_in->[0], $bars_out->[0], $emp_id, $pre_pse_ids->[0]);
    
    unless($pse) {
	$self->{'Error'} = "Could not create process step.";
	return;
    }
	
    push (@$pses, $pse->pse_id);
    
    my $dna_pses = $self->GetDNAFromBarcodeProcess($bars_in->[0], $ps_id);
    unless($dna_pses) {
	$self->{'Error'} = "Could not get dna_pses.";
	return;
    }
    
	
    my %row_mapping = ('a' => [qw(a c e g)],
		       'b' => [qw(b d f h)]);

    foreach my $dna_pse (@$dna_pses) {

	my $row = substr($dna_pse->location_name, 0, 1);
	my $col = substr($dna_pse->location_name, 1, 2);

	foreach my $row_well (@{$row_mapping{$row}}) {
	 
	    my $dl = GSC::DNALocation->get(location_name => $row_well.$col);
	    my $result = GSC::DNAPSE->create(pse_id => $pse->pse_id,
					     dna_id => $dna_pse->dna_id,
					     dl_id  => $dl->dl_id);
	    unless($result) {
		$self -> {'Error'} = "$pkg: ProcessDNA -> Failed creating DNAPSE.";
		return;
	    }
	}
    }

    return $pses;
}

sub CreatePcrFragments {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;


    my $input=0;
    my $pse_ids=[];

    my $separator;
    
    if($self -> {'PCROutputDualPrimer'}) {
	$separator = 3;
	my $num_outputs = ($#{$bars_out} + 1) % $separator;
	if($num_outputs != 0) {
	    $self->{'Error'} = "The number of outputs is invalid.";
	    return;
	}
    }
    else {
        $separator = 2;
	my $num_outputs = ($#{$bars_out} + 1) % $separator;
	if($num_outputs != 0) {
	    $self->{'Error'} = "The number of outputs is invalid.";
	    return;
	}


    }
    my $bar_in = $bars_in->[0]; 

    my $output=0;
    for($output=0;$output <= $#{$bars_out}; $output+=$separator) {
	


	# get the dna_pse connected to the barcode
	my $dna_pses = $self -> GetDNAFromBarcode($bar_in);
	$self->{'Error'} = "No dna connected to barcode.", return 0 unless($dna_pses);
	
	
	# Create the pse and link the barcodes to the pse, complete the prior pse
	my $pse = $self -> ProcessOneInputToOneOutput($ps_id, $bar_in, $bars_out->[$output + $separator - 1], $emp_id, $pre_pse_ids->[0]);
	unless($pse) {
	    return;
	}
	
	# if this is a rearray then there may be multiple input pses that need to be compelted
	#This might be the problem.
	#foreach my $pre_pse_id (1 .. $#{$pre_pse_ids}) {
	foreach my $pre_pse_id (@{$pre_pse_ids}) {
	    my $prior_pse = GSC::PSE->get(pse_id => $pre_pse_id);
	    unless($prior_pse) {
		$self -> {'Error'} = "$pkg: ProcessDNA -> Failed get prior pse.";
	    }
    
	    
	    $prior_pse -> set(pse_status => 'completed',
			      pse_result => 'successful',
			      date_completed => App::Time->now );
	}


	push(@$pse_ids, $pse->pse_id);
    
	
	#loop through each dna and create the pcr_product and schedule the sequencing setups connected to directed_setup 
	foreach my $dnapse (@$dna_pses) {
	    
	    
	    
	    my $primer_1;
	    my $primer_2;
	    
	    #HANDLE THE CONTROL WELL DIRECTLY
	    if($dnapse->location_name eq 'h12') {
	        $primer_1 = GSC::Primer->get(primer_name => 'MP_CNTRL.1');
	        $primer_2 = GSC::Primer->get(primer_name => 'MP_CNTRL.2');
	    }
	    else {

		#get the primer id foreach well 
		if($separator == 3) {
		    $primer_1 = GSC::Primer->load(sql => [$self -> {'GetPrimerIdFromBarcodeAndLocation'},$dnapse->dl_id, $bars_out->[$output]]);
		    $primer_2 = GSC::Primer->load(sql => [$self -> {'GetPrimerIdFromBarcodeAndLocation'},$dnapse->dl_id, $bars_out->[$output +1]]);
		}
		else {
		    my @primers = GSC::Primer->load(sql => [$self -> {'GetPrimerIdFromBarcodeAndLocation'},$dnapse->dl_id, $bars_out->[$output]]);
		    if($#primers == 1) {
			# order is controled by the query
			 if($primers[0] -> primer_direction eq 'forward') {
			     $primer_1 = $primers[0];
			 }
			 else {
			     $primer_2 = $primers[0];
			 }
			 
			 if($primers[1] -> primer_direction eq 'reverse') {
			     $primer_2 = $primers[1];
			 }
			 else {
			     $primer_1 = $primers[1];
			 }
		    }
		    else {
			$self->{'Error'} = "Failed to fined two primers in well $dnapse->dl_id, $bars_out->[$output]].";
			return 0;
		    }
		    
		}
	    }

	    unless($primer_1 && $primer_2) {
		$self->{'Error'} = "Failed to find primers in well ".$dnapse->dl_id.", $bars_out->[$output]].";
		return 0;
		
	    }

	    #get the directed setup dna for the dna and primers
	    my @ds_dnas = GSC::DirectedSetupDNA->load(sql=>["SELECT  distinct dsdna.* from 
							pcr_setup ps, 
							setup s,
							directed_setup ds,
							directed_setup_dna dsdna,
							dna_pse dp,
							process_step_executions pse, 
							pse_barcodes pb1,
							pse_barcodes pb2
							WHERE
							pb1.pse_pse_id = pse.pse_id and
							ps.pcr_setup_id = ds.setup_id AND
							ds.setup_id= s.setup_id and
							ds.ds_id = dsdna.ds_id AND
							dp.pse_id = pb2.pse_pse_id and
							dsdna.pse_id = pb1.pse_pse_id AND
							dp.dl_id  = ? and
							dsdna.created_dna_id is null AND
							dsdna.source_dna_id = ?  and
							ps.pri_id_1 = ? AND
							ps.pri_id_2 = ? AND
							pb1.bs_barcode = ? and
							pb1.bs_barcode= pb2.bs_barcode and
							pb2.direction= 'out' and
							(pse.psesta_pse_status = 'inprogress' or 
							 (pse.psesta_pse_status = 'completed' and pr_pse_result = 'successful'))",  
                                                            $dnapse->dl_id, $dnapse->dna_id, $primer_1->pri_id, $primer_2->pri_id, $bar_in]);
	    unless(@ds_dnas) {
		
		$self->{'Error'} = "The primer/dna combination does not have a directed setup entry.";
		return 0;
	    }
	    
	    my $dsdna = $self -> GetNextDs(@ds_dnas);
	    return 0 unless($dsdna);	    

	    my $this_ds = GSC::DirectedSetup->get($dsdna->ds_id);
	    my $pcr_setup = GSC::PCRSetup->get($this_ds->setup_id);
	    my $enz_id = $pcr_setup->enz_id;
	    
	    my $pcr_name;
	    if(defined $pcr_setup->setup_name) {
		$pcr_name = GSC::DNA -> get(dna_id => $dnapse->dna_id) -> dna_name . $pcr_setup->setup_name;
	    }

	    my $pcr_product = GSC::PCRProduct -> create(pri_id_1 => $primer_1->pri_id, 
							pri_id_2 => $primer_2->pri_id, 
							enz_id => $enz_id,
							parent_dna_id => $dnapse->dna_id,
							pse_id => $pse->pse_id,
							dl_id => $dnapse->dl_id,
							pcr_name => $pcr_name
							);
	    
	    
	    if(!$pcr_product) {
		$self->{'Error'} = "Couldn't create a PCR Product in the database.  Contact informatics";						    
		return 0;
	    }
	    
	    my $pcr_id = $pcr_product->pcr_id;
	    
	    # look up the directedsetup matching this pcr creation, and link
	    # the created dna now that the ID is known
	    
	    $dsdna->set(created_dna_id => $pcr_id);
	    
	    my @next_ds = GSC::DirectedSetup->get(prior_ds_id=>$this_ds->ds_id);
	    
	    # hop on through the next directed setups from here; link their source DNA refs to the 
	    # newly created PCR's
	    foreach my $nds (@next_ds) {
		
		unless(GSC::DirectedSetupPSE->is_loaded(pse_id =>$pse->pse_id,
							ds_id  => $nds->ds_id)) {
		    # create the direct_setup_pse entry 
		    my $dirsetup_pse = GSC::DirectedSetupPSE->create(pse_id =>$pse->pse_id,
								     ds_id  => $nds->ds_id);
		}
		# now create the directed_setup_dna link for the next step in the process
		my $seqdna = GSC::DirectedSetupDNA->create(pse_id => $pse->pse_id,
							   ds_id  => $nds->ds_id,
							   source_dna_id => $pcr_id);

		unless($seqdna) {
		    $self->{'Error'} = "Creating the DirectedSetupDNA failed.";
		    return;
		}
	    }
	    
	    
	}	    
    }
    return $pse_ids;
}



sub PcrTransfer2Gel {
    
    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
    
    my $pse_ids = [];
    my $gel_info=[];
    my $row = 1;
    my $gel_loc = 0;
    my $in_count = 0;

    foreach my $bar_in (@$bars_in) {

	if($bar_in !~ /^empty/) {
	    
	    my ($result, $prior_pses) = $self -> GetAvailBarcodeInInprogress($bar_in, $ps_id);
	    
	    unless($prior_pses) {
		$self->{'Error'} = "Could not find prior pse.";
		return;
	    }
	    
	    my $pse_obj = $self -> ProcessOneInputToOneOutput($ps_id, $bar_in, $bars_out->[0], $emp_id, $prior_pses->[0]);
	    unless($pse_obj) {
		return;
	    }
	    
	    # set prior pse to inprogress for this step since it is a fork in the processing
	    my $result = GSC::PSE->get(pse_id => $prior_pses->[0]) -> set(pse_status => 'inprogress',
								    pse_result => undef);
	    
	    
	    unless($result) {
		$self -> {'Error'} = "$pkg: VerifyGel -> Failed updating PSE.";
		return;
	    }
	    
	    push(@$pse_ids, $pse_obj->pse_id);

	    my @dna_pse_obj = GSC::DNAPSE->load(sql => [qq/select dp.* from dna_pse dp, pse_barcodes pb 
							where 
							dp.pse_id = pb.pse_pse_id 
							and direction = 'out' 
							and bs_barcode = ?/, $bars_in]);
	    
	    # this a temporary hack to get the name to parse out the funded project prefix
	    # this should be removed when you can find a funded project via the dna hierachy
	    my $dna_name = GSC::PCRProduct->get(dna_id => $dna_pse_obj[0]->dna_id)->pcr_name;
	    if($dna_name !~ /H_/) {
		# get the next one because the first on may be the control well
		$dna_name = GSC::PCRProduct->get(dna_id => $dna_pse_obj[1]->dna_id)->pcr_name;
	    }
	    my ($fp_prefix) = $dna_name =~ /^(.*)-.*$/;

	    my @rows2load;
	    if($fp_prefix eq 'H_AM') {
		foreach my $col (10, 11) {
		    foreach my $row ('a' .. 'h') {
			push @rows2load, $row.$col;	
		    }
		}
	    }
	    else {
		
		# These are the default rows to load
		@rows2load = ('d','h');
		
		# IF the first load fails then reload a and h
		$self -> {'CheckLoadStatus'} -> execute($bar_in, 'unsuccessful');
		my ($fail_count) = $self-> {'CheckLoadStatus'} -> fetchrow_array;
		
		if($fail_count == 1) {
		    @rows2load = ('a', 'h');
		}
	    
	    }


	    foreach my $plate_row (@rows2load) {


		$self -> {'GetPcrIdPlIdFromPcrBarRow'} -> execute($bar_in, $plate_row.'%');
		my $lol =  $self -> {'GetPcrIdPlIdFromPcrBarRow'} -> fetchall_arrayref;
		
		unless($lol) {
		    $self->{'error'} = "$pkg: PcrTransfer2Gel -> Could not find row to load.";
		    return 0;
		}
		
		
		foreach my $row_data (@{$lol}) {
		    my $pcr_id = $row_data->[0];
		    my $well_96 = $row_data->[1];
		    my $pl_id = $row_data->[2];
		    my $name = $row_data->[3];
		    
		    
		    #load  gel with 24 on the top and bottom of each with an 8 channel loader
		    my @values = &ConvertWell::Parse96($well_96);
		    my ($plate, $well, $col, $suffix) = @values;

		    # convert the well to the gel lane
		    my $mcol = (($row - 1) % 2);
		    my $lane = ($col - 1)  + ($col) + ($mcol * 1) + ($gel_loc * 24);
		    
		    my $dnapse_obj = GSC::DNAPSE -> create(pse_id => $pse_obj->pse_id,
							   dna_id => $pcr_id,
							   dl_id  => $lane+1000);
		    
		    $gel_info->[$lane] = $name;
		    
		}
		
		$row++;
		
	    }
	    $in_count++;	    
	}
	else {
	    $row+=2;
	}
	
	$gel_loc++;
    }

    # Create the print out for the gel
    my $result = $self -> CreateGelInfoSheets($bars_out->[0], $emp_id, $gel_info);

    return  $pse_ids;
}



sub CreateGelInfoSheets {
			 
    my ($self, $barcode, $emp_id, $gel_info) = @_;

    my $date = App::Time->now;
    my $user_obj = GSC::User->load(sql => [qq/select gu.* from gsc_users gu where gu_id in 
				   (select gu_gu_id from employee_infos where ei_id = '$emp_id')/]);
    my $user = $user_obj->unix_login;

    my $num_lanes = 24;
    my $table_header = ['Gel Lane', 'PCR Name'];
    
    
    my $gif_file = '/tmp/barcode.png';
    my $ps_file = '/tmp/barcode.ps';
    my $backup = "/tmp/GelInfoSheet.$barcode";
    
    open(FILE, ">$backup");
    
    print FILE "barcode = $barcode\n";
    print FILE "user = $user\n";
    print FILE "date = $date\n";
    print FILE "num lanes = $num_lanes\n";
    print FILE "Gel Lane = PCR NAME\n";
    
    for my $i (0 .. 1) {
	
	my @lanes = @$gel_info[1 .. 48];
	@lanes = @$gel_info[49 .. 96] if($i==1);

	my $col=0;
	
	my $bar_image = new BarcodeImage($barcode,10,"bw",1,200,"interlaced", '');
	
	my $log_sheet = TouchScreen::GelImageLogSheet->new(500, 700);
	
	$log_sheet -> InsertBarcode($bar_image->{gd_image}, 300, 15);
	
	$log_sheet -> InsertString(50, 25, "Gel Type   : PCR check gel");
	$log_sheet -> InsertString(50, 35, "Technician : $user");
	$log_sheet -> InsertString(50, 45, "Date       : $date");
	
	my $x = 50;
	my $y = 70;
	my $incrX = 75;
	my $incrY = 10;
	
	$log_sheet -> InsertString($x, $y, 'Lane');
	$log_sheet -> InsertString($x+$incrX, $y, 'PCR Name');
	
	my $cntr = 1;
	$cntr = 49 if($i==1);
	foreach my $lane  (@lanes) {
	    $y+= $incrY;
	    $log_sheet -> InsertString($x, $y, $cntr);
	    $log_sheet -> InsertString($x + 35, $y, $lane);
	    print FILE "$cntr = $lanes[$cntr]\n";
	    $cntr++;
	    if(($cntr == 25)||($cntr == 73)) {
		$x = 250;
		$y = 70;
		$log_sheet -> InsertString($x, $y, 'Lane');
		$log_sheet -> InsertString($x+$incrX, $y, 'PCR Name');
	    }
	}
	
	
	my $under='';
	for(my $z=0; $z<$x/2; $z++) {
	    $under = $under.'_';
	}
	$log_sheet -> InsertString(50, 70, $under);
	 
	my @lanes_top = @$gel_info[1 .. 24];
	my @lanes_bot = @$gel_info[25 .. 48];

	@lanes_top = @$gel_info[49 .. 72] if($i==1);
	@lanes_bot = @$gel_info[73 .. 96] if($i==1);
	$log_sheet -> CreateGelImage(50, 450, 320, 150, $num_lanes, \@lanes_top, \@lanes_bot);
	

	my $gif_image = $log_sheet->CreateImage;
	open(GIF, ">$gif_file") || die("Can't open GIF file");
	binmode GIF;
	print GIF $gif_image;
	close(GIF);
	
	
	`lpr -o scaling=100 $gif_file`;

    }

    close(FILE);
  
}


sub VerifyGel {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

    my @failed_gel_lane;
    my $data_options = $options->{'Data'};
    
    my $pse_ids = [];
    my @control_wells = ('h12');	
    

    my %fp_gel_requirements = ('H_AD' => {'pass minimum' => 11,
					  'cntrl wells' => [],
				      },
			       'H_AK' => {'pass minimum' => 11,
					  'cntrl wells' => ['h1', 'h11'],
				      },
			       
			       'H_AL' => {'pass minimum' => 11,
					  'cntrl wells' => ['h1', 'h11'],
				      },
			       );
			       


    if(defined $data_options) {
        foreach my $pso_id (keys %{$data_options}) {
            my $info = $data_options -> {$pso_id};
            if(defined $info) {
                my $pso_obj = GSC::ProcessStepOutput->get(pso_id => $pso_id);
                if($pso_obj->output_description eq 'Fail Gel Selection') {
                    if((defined $$info) && ($$info ne '') && ($$info ne 'select failed gels')) {
                        @failed_gel_lane = split(/\t/, $$info);
                    }
                }
            }
        }
    }


    foreach my $prior_pse (@$pre_pse_ids) {

	
	my $pse_obj = $self -> ProcessOneInputToOneOutput($ps_id, $bars_in->[0], $bars_out->[0], $emp_id, $prior_pse);
	unless($pse_obj) {
	    return;
	}
	    
	push(@$pse_ids, $pse_obj->pse_id);

	
	my $fail_pse_obj;
	if($#failed_gel_lane != -1) {
	    $fail_pse_obj = $self -> ProcessOneInputToOneOutput($ps_id, $bars_in->[0], $bars_out->[0], $emp_id, $prior_pse);
	    $fail_pse_obj->set(pse_status => 'abandoned',
			       pse_result => 'terminated');
	    unless($fail_pse_obj) {
		return;
	    }
	    
	}
	# determine the status for the entire run
	# status depends upon the number of gels that failed (the number needed to cause a failure depends upon funded project)
	# status depends upon whether or not control wells failed (which wells are control wells depends upon the funded project)
	
	#
	# code for definition of control wells and determination of $status goes here
	#

	my @dna_pse_obj = GSC::DNAPSE->load(sql => [qq/select dp.* from dna_pse dp, pse_barcodes pb 
					    where 
					    dp.pse_id = pb.pse_pse_id 
					    and direction = 'out' 
					    and bs_barcode = ? 
					    and pb.pse_pse_id = ?/, $bars_in->[0], $prior_pse]);
	
	# this a temporary hack to get the name to parse out the funded project prefix
	# this should be removed when you can find a funded project via the dna hierachy
	my $dna_name = GSC::PCRProduct->get(dna_id => $dna_pse_obj[0]->dna_id)->pcr_name;
	if($dna_name !~ /H_/) {
	    # get the next one because the first on may be the control well
	    $dna_name = GSC::PCRProduct->get(dna_id => $dna_pse_obj[1]->dna_id)->pcr_name;
	}
	my ($fp_prefix) = $dna_name =~ /^(.*)-.*$/;
	push(@control_wells, @{$fp_gel_requirements{$fp_prefix}{'cntrl wells'}});

	my $status = 'pass';

	my $pass_cnt = 0;

	foreach my $dna_pse_obj (@dna_pse_obj) {
	    
	    my $gel_lane = $dna_pse_obj->location_name;
	    
	    
	    my $inlist = (grep(/^$gel_lane$/, @failed_gel_lane));
	    my $result;
	    if(!$inlist) {
		my $result = GSC::DNAPSE->create(pse_id => $pse_obj->pse_id,
						 dna_id => $dna_pse_obj->dna_id,
						 dl_id  => $dna_pse_obj->dl_id);
		unless($result) {
		    $self -> {'Error'} = "$pkg: ProcessDNA -> Failed creating DNAPSE.";
		    return;
		}
		
		my $dna_pse_obj = GSC::DNAPSE->load(sql => [ $self -> {'GetDNAPSEFromDNAandPSE'}, $dna_pse_obj->dna_id, $prior_pse]);

		# Count only pass locations that are not control wells
		$inlist = grep(/^$dna_pse_obj->location_name/, @control_wells);
		$pass_cnt++ if(!$inlist);
	    }
	    else {
		my $result = GSC::DNAPSE->create(pse_id => $fail_pse_obj->pse_id,
						 dna_id => $dna_pse_obj->dna_id,
						 dl_id  => $dna_pse_obj->dl_id);
		unless($result) {
		    $self -> {'Error'} = "$pkg: ProcessDNA -> Failed creating DNAPSE.";
		    return;
		}

		
		my $dna_fail_pse_obj = GSC::DNAPSE->load( sql => [$self -> {'GetDNAPSEFromDNAandPSE'}, $dna_pse_obj->dna_id, $prior_pse]);
		
									 
		$status = 'fail' if( $dna_fail_pse_obj->location_name eq 'h12');
		
		
	    }
	    
	}
	
        if($pass_cnt < $fp_gel_requirements{$fp_prefix}{'pass minimum'})  {
	    $status = 'fail';
	}

	
	if($status eq 'pass') {


	    my $result = $pse_obj->set(pse_status => 'completed', 
				       pse_result => 'successful'
				       );
	    
	    unless($result) {
		$self -> {'Error'} = "$pkg: VerifyGel -> Failed updating PSE.";
		return;
	    }
	}
	else {
	    
	    my $result = $pse_obj->set(pse_status => 'completed', 
				    pse_result => 'unsuccessful'
				    );

	    
	    unless($result) {
		$self -> {'Error'} = "$pkg: VerifyGel -> Failed updating PSE.";
		return;
	    }
	    # Get the number of times the dna has been loaded
	    $self -> {'NumberOfTimesLoaded'} -> execute($prior_pse);
	    my ($load_count) =  $self -> {'NumberOfTimesLoaded'}->fetchrow_array;

	    # fail any steps still in progress for the pcr_product dna that was loaded if it is the second attempt
	    if($load_count == 2) {
		
		$self -> {'Get384wellCleanupPse'} -> execute($prior_pse);
		my $inprog_pses = $self -> {'Get384wellCleanupPse'} -> fetchall_arrayref;
		foreach my $pse (@$inprog_pses) {
		    my $update = GSC::PSE->get(pse_id => $pse->[0])-> set(pse_status => 'completed', 
									  pse_result => 'unsuccessful'
								     );
		    
		    
		    unless ($update) {
			$self -> {'Error'} = "$pkg: PcrCheckGel() -> Could not find 384 well plate pse for failure $bars_in->[0].";
			return 0;
		    }
		}
		
	    }
	    
	}
    }


    return $pse_ids;
}





sub convert96to384 {
    my($self, $well, $sector_name) = @_;
	      my ($well_384) = &ConvertWell::To384($well, $sector_name);
	      #my $sector_name = $self -> GetSectorName($sec_id);
              my $sec_id = Query($self->{'dbh'}, qq/select sec_id from sectors where sector_name = '$sector_name'/);
	      return 0 if($sec_id eq '0');

	      my $pl384_id = $self->GetPlId($well_384, $sec_id,  $self -> {'CoreSql'} -> Process('GetPlateTypeId', '384'));
	      return 0 if($pl384_id eq '0');
	      #END
	     # my $pl_id = $row->[2];
    return $pl384_id;

}#convert96to384

sub SequencePcr96to384 {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
    
    my $pse_ids = [];
    
    #Get the Fx, Rx, PCRx = 1 set (2 quadrants)
    #my $reagent_brew = $self->GetReagentName($options->{'Reagents'}->{'1/32 H_AD Brew'}->{'barcode'});
    
    # attempt to pull in the reagent name
    my $get_reag_name = $self->GetReagentName($options->{'Reagents'}->{'Premix'}->{'barcode'});

    my %reagent = ( 
		    #LSF: If you want to use the brew, put it here.
		    "Premix" => ($get_reag_name) ? $get_reag_name : "Big Dye Premix",
		    );
    
    my $enz_id = $self -> GetEnzIdFromReagent($reagent{"Premix"});
    return 0 if(!$enz_id);
    
    my $dc_id = $self -> GetDcIdFromReagent($reagent{"Premix"});
    return 0 if(!$dc_id);
    
    my $dye_type_like = $self->getDyeTypeRootName($dc_id);
    unless($dye_type_like) {
	return 0;
    }
 
    my @sectors = qw(a1 a2 b1 b2);
   
    my $num_inputs = ($#{$bars_in} + 1) % 3;
    if($num_inputs != 0) {
	$self->{'Error'} = "The number of inputs is invalid.";
	return;
    }

    my $input=0;
    my $sector_pos = 0;
    for($input=0;$input <= $#{$bars_in}; $input+=3) {


	my $i = $input / 3;

	#get the source plate barcode
	my $bar_in = $bars_in->[($i*3)];

	next if($bar_in =~ /empty/);
	
	#get the primer plate barcodes
	my %primer_bars = ('forward' => $bars_in->[(($i*3)+1)],
			   'reverse' => $bars_in->[(($i*3)+2)],
			   );
	
	my ($result, $prior_pses) = $self -> GetAvailBarcodeInInprogress($bar_in, $ps_id);
	
	unless($prior_pses) {
	    $self->{'Error'} = "Could not find prior pse.";
	    return;
	}

	my $dnapse_query = "select distinct dp.*  
							from pse_barcodes pbx, dna_pse dp, process_step_executions pse,
							process_steps p
							where pbx.bs_barcode = '$bar_in'
							and pbx.pse_pse_id = dp.pse_id 
							and pse.pse_id = dp.pse_id 
							and pse.ps_ps_id = p.ps_id 
							and pro_process_to = 'create pcr fragment'";
	
	my @dnapse_objs =   GSC::DNAPSE -> load(sql => $dnapse_query);
						
#	my $dnapse_objs = $self -> GetDNAFromBarcode($bar_in);

	foreach my $direction ('forward', 'reverse') {
	    
	    my $sector = GSC::Sector->get(sector_name => $sectors[$sector_pos]);
	    unless($sector) {
		$self->{'Error'} = "$pkg: SequencePcr96to384 -> Could not get sector name.";
		return;
	    }

	    $sector_pos++;

	    next if($primer_bars{$direction} =~ /empty/);

	    my $pse_obj = $self->ProcessOneInputToOneOutput($ps_id, $bar_in, $bars_out->[0], $emp_id, $prior_pses->[0]);
	    unless($pse_obj) {
		return;
	    }
	    push(@$pse_ids, $pse_obj->pse_id);
	    

	    #For each quadrant well have different primer id.
	    foreach my $dnapse_obj (@dnapse_objs) {
		
		next if($dnapse_obj->location_name eq 'h12');
		#convert dna location
		my $dna_location = $dnapse_obj -> convert96to384(sector => $sector);
			      
		my $primer = GSC::Primer->load(sql => [$self -> {'GetPrimerIdFromBarcodeAndLocation'},$dnapse_obj->dl_id, $primer_bars{$direction}]);
		
		
		my @ds_dna = GSC::DirectedSetupDNA -> load(sql => [qq/select dsd.* from 
							   directed_setup_dna dsd, directed_setup ds, sequencing_setup ss
							   where 
							   dsd.ds_id = ds.ds_id and
							   ds.setup_id = ss.sequencing_setup_id and
							   dsd.source_dna_id = ? and
							   ss.pri_id = ? and 
							   ss.enz_id = ? and
							   dsd.created_dna_id is NULL and
							   ss.dc_id in (select dc_id from dye_chemistries where 
									   DYETYP_DYE_NAME like ?)/, $dnapse_obj->dna_id, $primer->pri_id, $enz_id, $dye_type_like]);

		unless(@ds_dna) {
		    $self -> {'Error'} = "$pkg: SequenceWithCustomPrimers() -> Could not find direct seq id.";
		    return 0;
		}
		
		# use the first ds_dna returned
		my $ds_dna = $self -> GetNextDs(@ds_dna);
		return 0 unless($ds_dna);
		
		
		
		my $seqdna = GSC::SeqDNA->create(pri_id        => $primer->pri_id, 
						 dc_id         => $dc_id,
						 enz_id        => $enz_id,
						 parent_dna_id => $dnapse_obj->dna_id,
						 pse_id        => $pse_obj->pse_id,
						 dl_id         => $dna_location->dl_id);

		
		my $result = $ds_dna -> set(created_dna_id => $seqdna->dna_id);
		unless($result) {
		    $self -> {'Error'} = "$pkg: SequenceWithCustomPrimers() -> Could not update created dna.";
		    return 0;
		}
	  }	
	    
	}
    }
    

    return $pse_ids;
} #SequencePcr384to384

sub getDyeTypeRootName {

    my ($self, $dc_id) = @_;

    my ($dye_type_name) = App::DB->dbh->selectrow_array(qq/select DYETYP_DYE_NAME from dye_chemistries where dc_id = $dc_id/);
    my $dye_type_like;
    if(defined $dye_type_name) {
	my ($dye_type, $ver) = split(/\sV/, $dye_type_name);
	$dye_type_like = '%'.$dye_type.'%';
    }
    else {
	$self->{'Error'} = "$pkg: SequencePcr384to384() -> Could not find dye type name for dc_id = $dc_id.";
       return 0;
    }
}


sub AddSeqControlBrew {
    
   my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
   
   my $pse_ids = [];
   my $update_status = 'completed';
   my $update_result = 'successful';
   my $status = 'inprogress';

   my $reagent_brew = $self->GetReagentName($options->{'Reagents'}->{'Brew'}->{'barcode'});
   #this is the default for testing
   $reagent_brew = '1/24pOT BDv3.1 FWD Brew' if(!defined $options->{'Reagents'}->{'Brew'}->{'barcode'});
   return 0 if(!$reagent_brew);


     
   my $enz_id = $self -> GetEnzIdFromReagent($reagent_brew);
   return 0 if(!$enz_id);
   
   my $pri_id = $self -> GetPriIdFromReagent($reagent_brew);
   return 0 if(!$pri_id);
   
   my $dc_id = $self -> GetDcIdFromReagent($reagent_brew);
   return 0 if(!$dc_id);


   my $dye_type_like = $self->getDyeTypeRootName($dc_id);
   unless($dye_type_like) {
       return 0;
   }

   
   for my $i (0 .. $#{$pre_pse_ids}) {    
	
	
       my $pre_bar_info = App::DB::dbh->selectall_arrayref(qq/select distinct bs_barcode, sec_sec_id, sector_name 
							   from pse_barcodes pb, seq_dna_pses sp, plate_locations, sectors
							   where 
							   sec_id = sec_sec_id
							   and
							   pl_id = pl_pl_id and
							   pb.pse_pse_id = sp.pse_pse_id and 
							   direction = 'in' and pb.pse_pse_id = $pre_pse_ids->[$i]/);
       
       

       unless($pre_bar_info) {
	   $self->{'Error'} = "$pkg: AddSeqControlBrew() -> Failed finding input barcode.";
	   return 0;
       }


       my $pse_obj = $self->ProcessOneInputToOneOutput($ps_id, $pre_bar_info->[0][0],  $bars_in->[0], $emp_id, $pre_pse_ids->[$i]);
       unless($pse_obj) {
	   return;
       }
       push(@$pse_ids, $pse_obj->pse_id);
       

       my $dna_pse = GSC::DNAPSE->load(sql => [qq/select dp.* from dna_pse dp, dna_location dl, pse_barcodes pb,
					       process_step_executions pse, process_steps  where 
					       pse.ps_ps_id = ps_id and
					       pse.pse_id = dp.pse_id and 
					       dp.dl_id = dl.dl_id and
					       pb.pse_pse_id = dp.pse_id and
					       location_name = 'h12' and
					       pro_process_to = 'create pcr fragment' and
					       bs_barcode  = '$pre_bar_info->[0][0]'/]);
       
       

       # some partial rearray plates don't have h12, so don't do this stuff but logg the step
       if(defined $dna_pse) {
	   
	   my $dna_location = $dna_pse -> convert96to384(sector => $pre_bar_info->[0][2]);
	   
	   
	   my $seqdna = GSC::SeqDNA->create(pri_id        => $pri_id, 
					    dc_id         => $dc_id,
					    enz_id        => $enz_id,
					    parent_dna_id => $dna_pse->dna_id,
					    pse_id        => $pse_obj->pse_id,
					    dl_id         => $dna_location->dl_id);
	   
	   
	   ### Multiple ds_dnas are returned; we only want the first one that's not been associated with created DNA
	   ### The API will take care of hiding used ones, in spite of the query still returning them until it's been sync'ed
	   
	   my @ds_dnas = GSC::DirectedSetupDNA -> load(sql => [qq/select dsd.* from 
							       directed_setup_dna dsd, directed_setup ds, sequencing_setup ss
							       where 
							       dsd.ds_id = ds.ds_id and
							       ds.setup_id = ss.sequencing_setup_id and
							       dsd.source_dna_id = ? and
							       ss.pri_id = ? and 
							       ss.enz_id = ? and
							       dsd.created_dna_id is NULL and
							       ss.dc_id in (select dc_id from dye_chemistries where 
									    DYETYP_DYE_NAME like ?)/, $dna_pse->dna_id, $pri_id, $enz_id, $dye_type_like]);
	   
	   
	   unless($#ds_dnas > -1) {
	       $self -> {'Error'} = "$pkg: SequenceWithCustomPrimers() -> Could not find direct seq id.";
	       return 0;
	   }
	   
	   # use the first ds_dna returned
	   my $ds_dna = $self -> GetNextDs(@ds_dnas);
	   return 0 unless($ds_dna);
	   
	   my $result = $ds_dna -> set(created_dna_id => $seqdna->dna_id);
	   
	   unless($result) {
	       $self -> {'Error'} = "$pkg: SequenceWithCustomPrimers() -> Could not update created dna.";
	       return 0;
	   }
       }

   }
	    

   return $pse_ids;

}


sub GetNextDs {
    

    my ($self, @ds_dnas) = @_;
    foreach my $ds_dna (@ds_dnas) {
	
	next if(defined $ds_dna->created_dna_id);
	
	return $ds_dna;
    }	
    
    $self->{'Error'} = "$pkg:  SequenceWithCustomPrimers() -> Failed setting directed_setup_dna.";
    return;
}

1;

# $Header$
