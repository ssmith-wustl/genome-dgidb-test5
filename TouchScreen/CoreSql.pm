# -*-Perl-*-

##############################################
# Copyright (C) 2001 Craig S. Pohl
# Washington University, St. Louis
# All Rights Reserved.
##############################################

package TouchScreen::CoreSql;

use strict;
use ConvertWell;
use DbAss;
#use Mail::Send;
use PP::PBS;
use PP;
#############################################################
# Coreuction sql code package
#############################################################

require Exporter;


our @ISA = qw (Exporter AutoLoader);
our @EXPORT = qw ( );

my $pkg = __PACKAGE__;

#########################################################
# Create a new instance of the CoreSql code so that you #
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
    if($schema eq 'tlakanen') {
	$self->{'PkgOwner'} = 'tlakanen';
    }
    else {
	$self->{'PkgOwner'} = 'gsc';
    }

    $self->{'GetPrePseForBarcode'} =  LoadSql($dbh, "select distinct pse_pse_id from pse_barcodes 
            where bs_barcode = ? and direction = ? and 
            pse_pse_id in (select pse_id from process_step_executions 
            where psesta_pse_status = ? and ps_ps_id in 
            (select ps.ps_id from process_steps ps where ps.pss_process_step_status = 'active' and (ps.pro_process_to, ps.purpose) in
            (select ps1.pro_process, decode(ps1.gro_group_name, 'library core', ps.purpose, ps1.purpose) from process_steps ps1 where ps1.ps_id = ?)))",'List');
    
    $self->{'UpdatePse'} = LoadSql($dbh,"update process_step_executions set PSESTA_PSE_STATUS = ?,
               pr_pse_result = ?, DATE_COMPLETED = sysdate where pse_id = ?");
    
    $self->{'UpdatePseWithPriorPse'} = LoadSql($dbh,"update process_step_executions set PSESTA_PSE_STATUS = ?,
               pr_pse_result = ?, prior_pse_id = ?, DATE_COMPLETED = sysdate where pse_id = ?",
                                             undef,
                                             sub { GSC::PSE::_CreateOrUpdateTppPSEAutomaticly($_[3],$_[2])});
    
    $self->{'GetPseSession'} = LoadSql($dbh,"select pse_session from process_step_executions where pse_id = ?", 'Single');

    $self->{'GetNextPse'} = LoadSql($dbh,"select PSE_SEQ.nextval from dual", 'Single') if(App::DB->db_access_level eq 'rw');
    
    $self->{'InsertPseEvent'} = LoadSql($dbh,"insert into process_step_executions 
	    (PSE_SESSION,DATE_SCHEDULED,
           PSESTA_PSE_STATUS, PR_PSE_RESULT, PS_PS_ID,EI_EI_ID,PSE_ID,
            EI_EI_ID_CONFIRM, PIPE, PRIOR_PSE_ID) 
	    values (?, sysdate, ?, ?, ?, ?, ?, ?, ?, ?)",
                                        undef,
                                        sub { GSC::PSE::_CreateOrUpdateTppPSEAutomaticly($_[5],$_[8]); });

    $self->{'InsertBarcodeEvent'} = LoadSql($dbh,"insert into pse_barcodes 
	    (bs_barcode, pse_pse_id, direction, psebar_id) 
	    values (?, ?, ?, psebar_seq.nextval)");
	
    $self -> {'CountBarcodeUse'} = LoadSql($dbh, "select count(*) from pse_barcodes where 
                               bs_barcode = ? and direction = ?", 'Single');
	
    $self->{'BarcodeDesc'} = LoadSql($dbh, "select barcode_description from BARCODE_SOURCES where BARCODE = ?", 'Single');

    $self->{'GetPsId'} = LoadSql($dbh, "select ps_id from process_steps where purpose = ? and pro_process = ? and pro_process_to = ?
                and PSS_PROCESS_STEP_STATUS = 'active' and 
                 output_device = ? and gro_group_name = ?", 'Single');
       
    $self->{'InsertBarcode'} = LoadSql($dbh, "insert into barcode_sources (ps_ps_id, barcode, barcode_description) values (?, ?, ?)"); 
    
    $self->{'GetPlateTypeId'} = LoadSql($dbh, "select pt_id from plate_types where well_count = ?", 'Single');
    $self->{'GetSectorIds'} = LoadSql($dbh, "select sec_id from sectors where sector_name like ? order by sec_id", 'List');
    $self->{'GetSectorId'} = LoadSql($dbh, "select sec_id from sectors where sector_name = ?", 'Single');
    $self->{'GetGroupForPsId'} = LoadSql($dbh, "select gro_group_name from process_steps where ps_id = ?", 'Single');

    
    $self -> {'GetAvailBarcode'} =  "select distinct pse.* 
	from 
	pse_barcodes barx, 
	process_step_executions pse
	where 
	barx.pse_pse_id = pse.pse_id and
	pse.psesta_pse_status in ( ?, ? ) and 
	barx.bs_barcode = ? and barx.direction = ? and pse.ps_ps_id in 
	(select ps3.ps_id from process_steps ps1, process_steps ps2, process_steps ps3 
           where ps2.pro_process = ps3.pro_process_to and ps1.pro_process_to = ps2.pro_process_to 
           and ps1.ps_id = ? and (ps1.purpose = ps3.purpose or ps1.pro_process_to like 'claim%' or (ps3.purpose like 'Non-Barcoded Finishing' and ps3.gro_group_name = 'berg'))) order by pse.pse_id";

    $self->{'GetDNAPSEFromBarcode'} = "select dp.* from dna_pse dp, pse_barcodes pb 
	where 
	dp.pse_id = pb.pse_pse_id 
	and direction = 'out' 
	and bs_barcode = ?";
    $self->{'GetDNAPSEFromPSE'} = "select dp.* from dna_pse dp
	where 
	dp.pse_id = ?";

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
# Destroy a Coresql session #
#############################
sub destroy {
    my ($self) = @_;

    undef %{$self}; 
    $self ->  DESTROY;
} #destroy
  
 
############################################################################################
#                                                                                          #
#                            Main Subrotine Processes                                      #
#                                                                                          #
############################################################################################

sub Process {

    my ($self, $option, @vars) = @_;

    my $result = $self->{$option}->xSql(@vars);

    if(defined $result) {
	$self->{'Error'} = undef;
	return $result;
    }
    elsif(defined $DBI::errstr){
	$self->{'Error'} = "$pkg: Process()".$DBI::errstr;
    }
    else {
	$self->{'Error'} = "$pkg: Process()".$self->{$option}."with @vars.";
    }
    return 0;

}

=head1 sequence_dna_creation

Sequence dna creation is called by the post confirmation to spawn the blade job.
Since it is standard, this should be moved to the CoreSql.

=cut

sub confirm_pse_scheduling {
    my($self, $pses) = @_;
    #my $class = ref($self) ? ref($self) : $self; 
    foreach my $pse_id (@$pses) {
	my $pse = GSC::PSE->get($pse_id);
        if ($pse->pse_status ne "scheduled") {
            main::WriteToLog("Skipping explicit confirmation of PSE $pse_id "
                . "because the status is " . $pse->pse_status);
            next;
        }
	my $ps = $pse->get_process_step;
	if($ps->pp_type eq 'lsf'){
	    main::WriteToLog("Status is scheduled for ".$pse->pse_id.".  LSF cron should pick this up.");
	    next;
	}

	unless($pse->confirm_scheduling()){
            $pse = GSC::PSE->load($pse->id);
            if ($pse->pse_status ne "scheduled") {
                main::WriteToLog("Race to confirm PSE $pse_id.  Skipping direct qsub by the touchscreen." . $pse->pse_status);
                next;
            }
	    $self->{'Error'} ="We failed to confirm scheduled pse $pse_id : ".$pse->error_message;
	    return;
	}
    }      
    1; 
}


sub xOneToManyProcess {

    my ($self, $ps_id, $pre_pse_id, $update_status, $update_result, $bar_in, $bars_out, $emp_id) = @_;
    
    my $session = $self->Process('GetPseSession', $pre_pse_id) if(defined $pre_pse_id);
    $session = 0 if(! $session);

    my $result;
    #If $update_status and $update_result does not exist, we assume
    #the user do NOT want to update the prior pse id status
    if(defined $pre_pse_id && ($update_status || $update_result)) {
        my $result =  $self->Process('UpdatePse', $update_status, $update_result, $pre_pse_id);
	return 0 if(!$result);
    }
    
    my $new_pse_id =  $self->Process('GetNextPse');
    return 0 if(! $new_pse_id);
    
    #PSE_SESSION,DATE_COMPLETED,PSESTA_PSE_STATUS, PR_PSE_RESULT, PS_PS_ID, EI_EI_ID, PSE_ID, EI_EI_ID_CONFIRM, PIPE
    $result = $self->Process('InsertPseEvent', $session, 'inprogress', '', $ps_id, $emp_id, $new_pse_id, $emp_id, 0, $pre_pse_id ? $pre_pse_id : 0);
#PSE_SESSION,DATE_SCHEDULED,
#            PSESTA_PSE_STATUS, PR_PSE_RESULT, PS_PS_ID,EI_EI_ID,PSE_ID,
#            EI_EI_ID_CONFIRM, PIPE) 
#	    values (?, sysdate, ?, ?, ?, ?, ?, ?, ?)
    return 0 if(! $result);

    
    
    #bs_barcode, pse_pse_id, direction
    $result = $self->Process('InsertBarcodeEvent', $bar_in, $new_pse_id, 'in') if(defined $bar_in);
    return 0 if(! $result);
    
    if(defined $bars_out->[0]) {
	foreach my $bar_out (@{$bars_out}) {
	    $result = $self->Process('InsertBarcodeEvent', $bar_out, $new_pse_id, 'out');
	    return 0 if(! $result);
	}
    }
    
    return ($new_pse_id);
}


sub BarcodeProcessEvent {

    my ($self, $ps_id, $bar_in, $bars_out, $status, $pse_result, $emp_id, $session, $pre_pse_id) = @_;
    
    $session = 0 if(!defined $session);
    
    my $new_pse_id =  $self->Process('GetNextPse');
    return (0) if(!$new_pse_id);
    
    my $result = $self->Process('InsertPseEvent', $session, $status, $pse_result, $ps_id, $emp_id, $new_pse_id, $emp_id, 0, $pre_pse_id ? $pre_pse_id : 0);
    return (0) if(! defined $result);
    
    #bs_barcode, pse_pse_id, direction
    if(defined $bar_in) {
	$result = $self->Process('InsertBarcodeEvent', $bar_in, $new_pse_id, 'in');
	return (0) if(! defined $result);
    }

    if(defined $bars_out->[0]) {
	foreach my $bar_out (@{$bars_out}) {
	    $result = $self->Process('InsertBarcodeEvent', $bar_out, $new_pse_id, 'out');
	    return (0) if(! defined $result);
	}
    }
    
    $result =  $self->Process('UpdatePse', $status, $pse_result, $new_pse_id);
    return 0 if(! defined $result);
 
    return $new_pse_id;
}


#############################################
# Get the Barcode Description for a barcode # 
#############################################
sub CheckIfUsed{
    my ($self, $barcode, $direction) = @_;

    if($self->{'CountBarcodeUse'} -> xSql($barcode, $direction) == 0) {
	
	my $bar_desc = $self->{'BarcodeDesc'} -> xSql($barcode);
	if(defined $bar_desc) {
	    return $bar_desc;
	}
        elsif(defined $DBI::errstr){
	    $self->{'Error'} = $DBI::errstr;
	}
	else {
	    $self->{'Error'} = "Could not find description information for barcode = $barcode.";
	}	

    }
    elsif(defined $DBI::errstr){
	$self->{'Error'} = $DBI::errstr;
    }
    else {
	$self->{'Error'} = "Could not determine count for barcode = $barcode.";
    }	

    return 0;

} #CheckIfUsed


sub GetNextBarcode {

    my ($self, $prefix, $ps_id, $desc) = @_;
    my $dbh = $self -> {'dbh'};
    my $schema = $self -> {'Schema'};
    my $barcode;
    $barcode = GSC::Barcode->create(barcode_prefix => $prefix) ;
=cut
    my $db_query = $dbh->prepare(q{
	BEGIN 
	    :mybarcode := gsc.NextBarcode.GetNextBarcode(:prefix);
	END;
	
    });
    
    my $db_answer;
    $db_query->bind_param(":prefix", $prefix);
    $db_query->bind_param_inout(":mybarcode", \$barcode, 8);
    $db_query->execute;
    
     if (defined $barcode)  {
	 #(ps_ps_id, barcode, barcode_description)
	 my $result = $self->Process('InsertBarcode', $ps_id, $barcode, $desc);
	 return 0 if(!$result);

	 return ($barcode);
     }

    $self->{'Error'} = "Could not get next barcode for prefix = $prefix.";
=cut
  
    return $barcode && $barcode->barcode ? $barcode->barcode : 0 ;
   
} #GetNextBarcode

###########################
# Insert DNA location pse #
###########################
sub InsertDNAPSE {
    
    my ($self, $dna_id, $pse_id, $dl_id) = @_;
    
    
    if($dl_id eq '') {
	$dl_id = 0;
    }

    my $result = GSC::DNAPSE->create(dna_id => $dna_id, 
				     pse_id => $pse_id, 
				     dl_id  => $dl_id);
    if($result) {
	return $result;
    }
    
    $self->{'Error'} = "$pkg: InsertDNAPSE() -> $dna_id, $pse_id, $dl_id";
    
    return 0;
} #InsertDNAPSE
 




# This ProcessDNA method should be used to do one input to one or none output barcodes #


sub ProcessOneInputToOneOutput {

    my ($self, $ps_id, $bar_in, $bar_out, $emp_id, $pre_pse_id, $no_update) = @_;

    my $prior_pse = GSC::PSE->get(pse_id => $pre_pse_id);
    
    
    unless($prior_pse) {
	$self -> {'Error'} = "$pkg: ProcessDNA -> Failed get prior pse.";
    }
    
    if(! $no_update) {
    $prior_pse -> set(pse_status => 'completed',
		      pse_result => 'successful',
		      ei_id_confirm => $emp_id,
		      date_completed => App::Time->now );
    }

    my $pse = GSC::PSE->create(prior_pse_id => $pre_pse_id,
			       pse_session => 0,
			       date_scheduled => App::Time->now,
			       ei_id => $emp_id,
			       pse_status => 'inprogress',
			       ps_id => $ps_id, 
			       pipe => 0);
    unless($pse) {
	$self -> {'Error'} = "$pkg: ProcessDNA -> Failed creating PSE.";
	return;
    }
    

    my $barin = GSC::PSEBarcode->create(barcode => $bar_in,
					    pse_id =>  $pse->pse_id,
					    direction => 'in');

    unless($barin) {
	$self -> {'Error'} = "$pkg: ProcessDNA -> Failed creating PSEBarcode.";
	return;
     }

    if(defined $bar_out) {
	my $barout = GSC::PSEBarcode->create(barcode => $bar_out,
						 pse_id =>   $pse->pse_id,
						 direction => 'out');    
	
	unless($barin) {
	    $self -> {'Error'} = "$pkg: ProcessDNA -> Failed creating PSEBarcode.";
	    return;
	}
    }

    return ($pse);
}

sub dna_source_pses{
    my $self = shift;
    my $barcode = shift;
    
    my $bc= GSC::Barcode->get(barcode => $barcode);
    my %dp = map {$_->pse_id => 1} $bc->get_dna_pse;
    return sort keys %dp;
}


sub ProcessDNA {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

    my $pses = [];
    my @pbs  = GSC::PSEBarcode->get(barcode => $bars_in->[0], direction => 'out');
    my %outpses = map { ( $_->pse_id => $_ ) } @pbs;
    my @dps  = GSC::DNAPSE->get(pse_id => \@pbs);
    my %hdps  = map { ( $_->dl_id => $_ ) } @dps;

    my $dont_update_prior = 0;
    my $data_options = $options->{'Data'};
    if(defined $data_options) {
	foreach my $pso_id (keys %{$data_options}) {
	    my $info = $data_options -> {$pso_id};
	    if(defined $info) {
		my $sql = "select OUTPUT_DESCRIPTION from process_step_outputs where pso_id = '$pso_id'";
		my $desc = Query($self->{'dbh'}, $sql);
		if($desc eq 'update prior status') {
		    if($$info eq 'inprogress') {
                        $dont_update_prior = 1;
		    }
		}
	    }
	}
    }

    my @dsp = $self->dna_source_pses($bars_in->[0]);
    return unless @dsp;
    foreach my $dna_source_pse(@dsp){
	my $prior;

	if(scalar(@$pre_pse_ids) == 1){
	    $prior = $pre_pse_ids->[0];
	}
	elsif(grep {$_ == $dna_source_pse} @$pre_pse_ids){
	    $prior = $dna_source_pse;
	}
	else{
	    ($prior) = App::DB->dbh->selectrow_array
		(qq/select pse_id from tpp_pse 
		 where pse_id in (/.join(',',@$pre_pse_ids).qq/)
		 start with prior_pse_id = $dna_source_pse
		 connect by prior pse_id = prior_pse_id/);
	}
	
	unless($prior){
	    $self->{Error} = "We cannot find the correct prior pse for the dna first dumped into this plate at pse $dna_source_pse";
	    return;
	}

	my $pse = $self -> ProcessOneInputToOneOutput($ps_id, $bars_in->[0], $bars_out->[0], $emp_id, $prior, $dont_update_prior);	
	unless($pse) {
	    $self->{'Error'} = "$pkg: ProcessDNA -> Failed creating PSE.";
	    return;
	}
        my @pdps = GSC::DNAPSE->get(pse_id => $dna_source_pse);
	return unless @pdps; #-- this is checked in the funciton that gives us the source pses

	foreach my $dp (@pdps) {
	    my $dna_pse = $hdps{$dp->dl_id};
	    unless($dna_pse) {
		#LSF: Put this here temporary to get the count colonies step through.
		#     The problem of the count colonies is that the prior step has the dna_pse dl_id 0.
		#     The output has the dl_id 2000 (tube).
		if(@pdps == 1 && keys %hdps == 1) {
		    ($dna_pse) = values %hdps;
		} else {
		    $self -> {'Error'} = "$pkg: ProcessDNA -> Failed to find DNAPSE.";
		    return;
		}	    
	    }
	    unless(GSC::DNAPSE->create(pse_id => $pse->pse_id,
				       dna_id => $dna_pse->dna_id,
				       dl_id  => $dna_pse->dl_id)) {
		$self -> {'Error'} = "$pkg: ProcessDNA -> Failed creating DNAPSE.";
		return;
	    }
	}
	push (@$pses, $pse->pse_id);
    }

    return $pses;
    
} #ProcessDna

sub NoTransfer {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

    my $pses = [];
    foreach my $prior_pse (@$pre_pse_ids) {
	my $pse = $self -> ProcessOneInputToOneOutput($ps_id, $bars_in->[0], $bars_out->[0], $emp_id, $prior_pse);
	
	unless($pse) {
	    return;
	}	
	push (@$pses, $pse->pse_id);
    }

    return $pses;
    
} #ProcessDna
sub ProcessDNAWithNoDNAPSE {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

    my $pses = [];
    foreach my $prior_pse (@$pre_pse_ids) {
	my $pse = $self -> ProcessOneInputToOneOutput($ps_id, $bars_in->[0], $bars_out->[0], $emp_id, $prior_pse);
	
	unless($pse) {
	    return;
	}
	
        #LSF: Keep it here for checking.
	my $bc = GSC::Barcode->get($bars_in->[0]);
	return unless $bc;
	my @dp = $bc->get_dna_pse;
	unless(@dp) {
	    $self->{Error} = 'No DNA in this plate!';
	    return;
	}
	push (@$pses, $pse->pse_id);
    }

    return $pses;
    
} #ProcessDna


sub ProcessDNAWithNoCompletion {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

    my $pses = [];
    foreach my $prior_pse (@$pre_pse_ids) {
	my $pse = $self -> ProcessOneInputToOneOutput($ps_id, $bars_in->[0], $bars_out->[0], $emp_id, $prior_pse, 1);
	
	unless($pse) {
	    return;
	}
	
	
	my $dna_pses = $self->GetDNAFromBarcode($bars_in->[0]);
	unless($dna_pses) {
	    return;
	}
	
	
	foreach my $dna_pse (@$dna_pses) {
	    my $result = GSC::DNAPSE->create(pse_id => $pse->pse_id,
					 dna_id => $dna_pse->dna_id,
					     dl_id  => $dna_pse->dl_id);
	    unless($result) {
		$self -> {'Error'} = "$pkg: ProcessDNA -> Failed creating DNAPSE.";
		return;
	    }
	}
	push (@$pses, $pse->pse_id);
    }

    return $pses;
    
} #ProcessDna


sub GetDNAFromBarcode {
    
    my ($self, $barcode) = @_;
    
    my @dna_pse = GSC::DNAPSE->load(sql => [$self->{'GetDNAPSEFromBarcode'}, $barcode]);
    
    unless(@dna_pse) {
	$self -> {'Error'} = "$pkg: GetDNAFromBarcode -> Failed loading DNAPSE.";
	return;
    }
    
    return \@dna_pse;
}



sub GetDNAFromPSE {
    
    my ($self, $pse) = @_;
    
    my @dna_pse = GSC::DNAPSE->load(sql => [$self->{'GetDNAPSEFromPSE'}, $pse]);
    
    unless(@dna_pse) {
	$self -> {'Error'} = "$pkg: GetDNAFromBarcode -> Failed loading DNAPSE.";
	return;
    }
    
    return \@dna_pse;
}









 
################################################################################
#                                                                              #
#                               Input verification subroutines                 #
#                                                                              #
################################################################################

sub GetAvailBarcodeInOutInprogress {

    my ($self, $barcode, $ps_id) = @_;
    my ($result, $pses) = $self -> GetAvailBarcodeInInprogress($barcode, $ps_id);
    return ($result, $pses) if($pses);
    return $self -> GetAvailBarcodeOutInprogress($barcode, $ps_id);
}

sub GetAvailBarcodeOutInprogress {

    my ($self, $barcode, $ps_id) = @_;

    my ($result, $pses) = $self -> GetAvailBarcode($barcode, 'out', $ps_id, 'inprogress');

    return ($result, $pses);

}

sub GetAvailBarcodeInInprogress {

    my ($self, $barcode, $ps_id) = @_;

    my ($result, $pses) = $self -> GetAvailBarcode($barcode, 'in', $ps_id, 'inprogress');

    return ($result, $pses);

}

sub GetAvailBarcodeInInprogressOrCompleted {

    my ($self, $barcode, $ps_id) = @_;

    my ($result, $pses) = $self -> GetAvailBarcode($barcode, 'in', $ps_id, 'inprogress', 'completed');

    return ($result, $pses);

}

sub GetAvailBarcodeOutInprogressOrCompleted {

    my ($self, $barcode, $ps_id) = @_;

    my ($result, $pses) = $self -> GetAvailBarcode($barcode, 'out', $ps_id, 'inprogress', 'completed');

    return ($result, $pses);

}

sub GetAvailBarcodeOutScheduled {

    my ($self, $barcode, $ps_id) = @_;

    my ($result, $pses) = $self -> GetAvailBarcode($barcode, 'out', $ps_id, 'scheduled');

    return ($result, $pses);

}

sub GetAvailBarcode {

    my ($self, $barcode, $direction, $ps_id, @status) = @_;

    return ($barcode) if($barcode =~ /^empty$/);

#    $status[1] = '' unless ($status[1]);
    my @pses = GSC::PSE->get(sql => [$self -> {'GetAvailBarcode'}, $status[0], $status[1], $barcode, $direction, $ps_id]);
    
    unless(@pses) {
	$self->{'Error'} = "$pkg: GetAvailBarcode() -> Barcode not in proper state for this step for barcode = $barcode, ps_id = $ps_id, status = @status.";
	return 0;
    }
    
    my $label = GSC::Barcode->barcode_label($barcode);

    my $pses = [];
    
    foreach (@pses) {
	push(@{$pses}, $_->pse_id);
    }

    return ($label, $pses);


} #GetAvailBarcode

sub GetAvailWholeBarcodeInOutInprogress {

    my ($self, $barcode, $ps_id) = @_;
    my ($result, $pses) = $self -> GetAvailWholeBarcode($barcode, "in", $ps_id, "inprogress");
    return ($result, $pses) if($pses);
    return $self -> GetAvailWholeBarcode($barcode, "out", $ps_id, "inprogress");
}

sub GetAvailWholeBarcode {

    my ($self, $barcode, $direction, $ps_id, @status) = @_;

    return ($barcode) if($barcode =~ /^empty$/);
    my $ps = GSC::ProcessStep->get(ps_id => $ps_id);
    my @pss = GSC::ProcessStep->get(process_to => $ps);
    my %opt;
    if($ps->process_to !~ /^claim/) {
      $opt{purpose} = $ps->purpose; 
    }
    my @tpss = GSC::ProcessStep->get(process_to => [ map { $_->process } @pss], %opt);
    
    my @pbs = GSC::PSEBarcode->get(direction => $direction, barcode => $barcode);
    my %tpses = map { ( $_->pse_id => $_ ) } GSC::PSE->get(pse_id => \@pbs, ps_id => \@tpss);
    my %s = map { ( $_ => 1 ) } @status;
    my @pses;
    my @not_done;
    foreach my $pse_id (keys %tpses) {
      if($s{$tpses{$pse_id}->pse_status}) {
        push @pses, $tpses{$pse_id};
      } elsif($tpses{$pse_id}->pse_status =~ /^confirm|^scheduled$/) {
        push @not_done, $tpses{$pse_id};
      }
    }
#    $status[1] = '' unless ($status[1]);
    #my @pses = GSC::PSE->load(sql => [$self -> {'GetAvailBarcode'}, $status[0], $status[1], $barcode, $direction, $ps_id]);
    if(@not_done) {
	$self->{'Error'} = "$pkg: GetAvailBarcode() -> Barcode not in proper state for this step for barcode = $barcode, ps_id = $ps_id, status = @status, pse_id = " . (join ",", (map { $_->pse_id . "|" . $_->pse_status } @not_done));
	return 0;    
    }
    unless(@pses) {
	$self->{'Error'} = "$pkg: GetAvailBarcode() -> Barcode not in proper state for this step for barcode = $barcode, ps_id = $ps_id, status = @status.";
	return 0;
    }
    #LSF: Make sure the @pses only from one step.  If it is from more than 1 step, give an error.
    if(scalar(keys %{{ map { ( $_->process_to => 1 ) } GSC::ProcessStep->get(ps_id => \@pses) }}) > 1) {
      $self->{'Error'} = "$pkg: GetAvailBarcode() -> Barcode has more than 1 from process step that valid for this step for barcode = $barcode, ps_id = $ps_id, status = @status.";
      return 0;      
    }
    
    my $label = GSC::Barcode->barcode_label($barcode);

    my $pses = [];
    
    foreach (@pses) {
	push(@{$pses}, $_->pse_id);
    }

    return ($label, $pses);


} #GetAvail384Barcode



sub CheckIfUsedAsOutput {
    
    my ($self, $barcode) = @_;
    
    my $desc = $self -> CheckIfUsed($barcode, 'out');
    return if(!$desc);
    return $desc;
    
} #CheckIfUsedAsOutput




sub GetReagentName {
    
   my ($self, $barcode) = @_;
 
   my ($reagent) =  $self->{'dbh'}->selectrow_array(qq/select rn_reagent_name from reagent_informations where bs_barcode = '$barcode'/);
   if(defined $reagent) {
       return $reagent;
   }
   
   $self->{'Error'} = "$pkg: GetReagentName() -> Could not find reagent for barcode = $barcode.";
   return 0;
   
} #GetReagentName


sub  GetEnzIdFromReagent {
    
    my ($self, $reagent) = @_;
    
    my ($enz_id) =  Query($self->{'dbh'}, qq/select enz_enz_id from enzymes_reagent_names where rn_reagent_name = '$reagent'/);
    if(! defined $enz_id) {
	$self -> {'Error'} = "$pkg: GetEnzIdFromReagent() -> Could not find enz_id.";
	return 0 ;
    }
    
    return $enz_id;
}
sub GetPriIdFromReagent {
    
    my ($self, $reagent) = @_;
 
    my $pri_id =  Query($self->{'dbh'}, qq/select pri_pri_id from primers_reagent_names where rn_reagent_name = '$reagent'/);
    if(! defined $pri_id) {
	$self -> {'Error'} = "$pkg: GetPriIdFromReagent() -> Could not find pri_id.";
	return 0 ;
    }


    return $pri_id;
}
sub GetDcIdFromReagent {
    
    my ($self, $reagent) = @_;
 
    my $dc_id = Query($self->{'dbh'}, qq/select dc_dc_id from dye_chemistries_reagent_names where rn_reagent_name = '$reagent'/);

    if(! defined $dc_id) {
	$self -> {'Error'} = "$pkg: GetDcIdFromReagent() -> Could not find dc_id.";
	return 0 ;
    }


    return $dc_id;
}

=head2 PrintBarcodes

 Print Barocdes and register with DB

 Parameters:
  $barcodes is the structure that 
                 contains the barcodes informaton
		 to be printed.  The structure is
		 shown below
	   {
	     $barcode => {
	       label => $label,
	       number => $numberofcopies, (if this does not defined the $amount will be used)
	     
	     },
	     ...
	   
	   
           }
 
   $amount is the number of copy to print if the "number" does not exist from above.
 
   $printer is the printer to print to.

=cut
sub PrintBarcodes {

    my ($self, $barcodes, $amount, $printer) = @_;

    my $temp_file = '/tmp/BarFromTouch';
    open(FILE, ">$temp_file") or do {     
      $self->{'Error'} = "$pkg: PrintBarcodes() -> Could not create temporary file.  Please contact hardware\@watson.wustl.edu.";
      return 1; };
    foreach my $barcode (sort keys %$barcodes) {
      for(my $i=0;$i< ($barcodes->{$barcode}->{number} ? $barcodes->{$barcode}->{number} : $amount);$i++) {
	if(defined $barcode) {
	  my $label = $barcodes->{$barcode}->{label} ? $barcodes->{$barcode}->{label} : $barcode;
	  if(length($label) > 25) {
	    print FILE "$barcode\t" . substr($label, 0, 25) . "\t$barcode\n";
          } else {
	    print FILE "$barcode\t",$label , "\t$barcode\n";
	  }
	  #print FILE "$barcode\t", ($barcodes->{$barcode}->{label} ? $barcodes->{$barcode}->{label} : $barcode), "\t$barcode\n";
	} else {
	  close(FILE);
          $self->{'Error'} = "$pkg: PrintBarcodes() -> Invalid barcode [$barcode] to print.";
          return 1;
	}  
      }
    }

    close(FILE);
    my $cmd = 'barlpr -P '.$printer.' '.$temp_file;
    if(system($cmd)) {
      $self->{'Error'} = "$pkg: PrintBarcodes() -> $!.";
      return 1;
    }
    return 0;
    
} #PrintBarcodes

=head2 Mail

 Mails list of user some Message

=cut
sub Mail {
  if($ENV{OSTYPE} ne 'MSWin32'){ eval 'use Mail::Send'; }
  my ($self, $users, $subject, $message) = @_;
  foreach my $user (@$users) {
    chomp $user;
    my $email = $user;

    my $mail = Mail::Send->new;
    $mail -> to($email);
    $mail -> subject($subject);
    my $fg = $mail -> open('sendmail');
    print $fg "\n\n$email,\n\n";
    print $fg "$message";
    $fg -> close;
  }
} #Mail

=head2 getBarcodeDescription

Get the Barcode Description

=cut
sub getBarcodeDescription {
  my $self = shift;
  my $barcode_text = shift;
  my $barcode_obj = GSC::Barcode->get(barcode => $barcode_text);
  if($barcode_obj) {
    return $barcode_obj->barcode_label();
  } else {
    $self->{'Error'} = "$pkg: getBarcodeDescription() -> Invalid barcode [$barcode_text].";
    return 0;
  }
}

#-----------------------------------
# Set emacs perl mode for this file
#
# Local Variables:
# mode:perl
# End:
#
#-----------------------------------
