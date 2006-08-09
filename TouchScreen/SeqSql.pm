# -*-Perl-*-

##############################################
# Copyright (C) 2003 Craig S. Pohl
# WASHINGTON University, St. Louis
# All Rights Reserved.
##############################################

package TouchScreen::SeqSql;

use strict;
use ConvertWell ':all';
use DbAss;
use TouchScreen::NewProdSql;

#############################################################
# Production sql code package
#############################################################

require Exporter;

our @ISA = qw(Exporter TouchScreen::CoreSql TouchScreen::NewProdSql);

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
 
    #Rearray DNA specific queries--maybe could be moved into coresql?
    $self->{'rearray_GetOrgIdFromPseId'}=LoadSql($dbh, qq(select distinct eav.value
                                                          from entity_attribute_value eav
                                                          where eav.attribute_name = 'org id'
                                                          and eav.type_name = 'dna'
                                                          and eav.entity_id IN (select dr.dna_id
                                                                                from dna_relationship dr
                                                                                start with dr.dna_id IN (select dp.dna_id
                                                                                                         from dna_pse dp
                                                                                                         where dp.pse_id = ?)
                                                                                connect by dr.dna_id = prior dr.parent_dna_id)), 'List');

    $self->{'rearray_GetSeqVlIdFromPSEId'}=LoadSql($dbh, qq(select distinct NVL(l.vl_vl_id, NVL(dri.vl_id, dnar.vl_id)), deer.priority
                                                            from (select dr.dna_id, level priority
                                                                  from dna_relationship dr
                                                                  start with dr.dna_id IN (select dp.dna_id
                                                                                           from dna_pse dp
                                                                                           where dp.pse_id = ?)
                                                                  connect by dr.dna_id = prior dr.parent_dna_id) deer
                                                            left outer join ligations l on l.lig_id = deer.dna_id
                                                            left outer join dna_resource dnar on dnar.dr_id = deer.dna_id
                                                            left outer join dna_resource_item dri on dri.dri_id = deer.dna_id
                                                            where l.vl_vl_id IS NOT NULL or dnar.vl_id IS NOT NULL or dri.vl_id IS NOT NULL
                                                            order by deer.priority), 'ListOfList');


    return $self;
} #new


################################################################################
#                                                                              #
#                               Input verification subroutines                 #
#                                                                              #
################################################################################

sub GetAvailClonesPassedQC {

my ($self, $barcode, $ps_id) = @_;

my $clone_data =  $self->{'dbh'} -> selectall_arrayref(qq/select distinct substr(c.clone_name, 0, length(c.clone_name) - 3) || ' ' || s.sector_name, clopre_clone_prefix, pse.pse_id from 
							 pse_barcodes barx, 
							 process_step_executions pse,
							 dna_pse cx,
							 clone_growths cg,
							 clones c,dna_pse dpi, dna_location dl, sectors s
							 where 
							 s.sec_id = dl.sec_id and
							 dpi.dl_id = dl.dl_id and
							 dpi.dna_id = c.clo_id and
							 c.clo_id = cg.clo_clo_id and
							 cg.cg_id = cx.dna_id and
							 barx.pse_pse_id = pse.pse_id and
							 pse.pse_id = cx.pse_id and 
							 pse.psesta_pse_status = 'completed' and 
							 barx.bs_barcode = '$barcode' and barx.direction = 'in' and pse.ps_ps_id in 
							 (select ps_id from process_steps where pro_process_to in
							  (select ps1.pro_process from process_steps ps, process_steps ps1 where ps.pro_process_to = ps1.pro_process_to and ps.ps_id = '$ps_id'))/);


if($clone_data) {
    my ($count_passed) =  $self->{'dbh'} -> selectrow_array(qq/select count(pse.pse_id) 
							    from        
							    process_steps ps
							    join process_step_executions pse on pse.ps_ps_id = ps.ps_id
							    join dna_pse dp on dp.pse_id = pse.pse_id 
							    join pse_data_outputs pdo on pdo.pse_pse_id = pse.pse_id
							    join process_step_outputs pso on pso.pso_id = pdo.pso_pso_id
							    where                                                              
							    pso.output_description = 'Gel QC'
							    and pdo.data_value = 'pass'                                                                                    
							and  pro_process_to = 'qc gel image'
							    and psesta_pse_status IN ('completed','inprogress')
							    and dp.dna_id  = (select dna_id
									      from process_step_executions pse
									  join pse_barcodes pb on pb.pse_pse_id = pse.pse_id
									      join dna_pse dp on dp.pse_id = pse.pse_id
									  where pb.direction = 'out'
									  and pb.bs_barcode = '$barcode'
									  and rownum = 1)/);
    if($count_passed) {

	return ($clone_data->[0][0], [$clone_data->[0][2]]);

    }
    $self->{'Error'} = "$pkg: barcode failed qc check.";
}

$self->{'Error'} = "$pkg: Not a valid barcode to claim.";
    return;

}


################################################################################
#                                                                              #
#                                            Input Defining Subroutines        #
#                                                                              #
################################################################################



################################################################################
#                                                                              #
#                                           Output Defining Subroutines        #
#                                                                              #
################################################################################



################################################################################
#                                                                              #
#                              Output verification subroutines                 #
#                                                                              #
################################################################################




############################################################################################
#                                                                                          #
#                         Confirm Subrotine Processes                                      #
#                                                                                          #
############################################################################################



sub ProcessDNAWithoutCompletion_old {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
    
    my $pse_ids = [];
    #my $plate_type = '384';
    my $update_status = 'inprogress';
    my $update_result = '';
    my $status = 'inprogress';
    
    my ($new_pse_id) = $self-> xOneToManyProcess($ps_id, $pre_pse_ids->[0], $update_status, $update_result, $bars_in->[0], $bars_out, $emp_id);
    my $result = $self -> CloneTrans96To96($bars_in->[0], $pre_pse_ids->[0], $new_pse_id);
    return 0 if($result == 0);
    return $new_pse_id;
}

sub RearrayDNAPlates {
    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options) = @_;
    
    my $pse_ids = [];
    my $plate_type = '384';
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $status = 'inprogress';
    
    my @sectors =  qw(a1 a2 b1 b2);
    
    for my $i (0 .. $#$bars_in) {
        if(!($bars_in->[$i]=~/^empty/)) {
            my $sec_id =  $self ->Process('GetSectorId', $sectors[$i]);
	    return ($self->GetCoreError) if(!$sec_id);

	    my $pre_pse_ids = $self ->Process('GetPrePseForBarcode', $bars_in->[$i], 'in', $status, $ps_id);
	    return 0 if(!$pre_pse_ids);

            my $pre_pse_id=$pre_pse_ids->[0];
	    
	    my ($new_pse_id) = $self-> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[$i], $bars_out, $emp_id);
	    
	    my $result = $self -> Trans96To384($bars_in->[$i], $pre_pse_id, $new_pse_id, $sec_id);
	    return 0 if($result == 0);

	    push(@{$pse_ids}, $new_pse_id);
    
	}
    }
    
    return $pse_ids;
} #RearraySequencPlates

sub GetAvailRearrayBarcodeInInprogress { #rearray version

    ##############################################################################
    #ISSUE:  WHAT CAN WE DO IF THE BACK BUTTON IS HIT?  HOW DO WE RESET THE THING?
    ##############################################################################

    my ($self, $barcode, $ps_id) = @_;

    if($barcode=~/^empty/) {
        return("rearray", []);
    }

    my ($result, $pses) = $self -> GetAvailBarcode($barcode, 'in', $ps_id, 'inprogress');

    unless($result) {
        return($result, $pses);
    }


    if(@$pses!=1) {
        return(0, $pses);
        #Something's wrong--but what do we do about it?
    }
    my $pse=GSC::PSE->get($pses);

    my $purpose=$pse->get_process_step()->purpose();
    
    my $org_id_ref=$self->Process('rearray_GetOrgIdFromPseId', $pse->id());
    
    if((@$org_id_ref!=1) && ($purpose ne 'Directed Sequencing')) {
        return(0, $pses);
        #Something's wrong here too--but what do we do about it?
    }
    my $org_id=shift(@$org_id_ref);

    my $vl_ids=$self->Process('rearray_GetSeqVlIdFromPSEId', $pse->id());
    my ($seq_vl_id)=$vl_ids->[0][0];
    unless(defined($seq_vl_id)) {
        #Again, something's terribly, terribly wrong
        return(0, $pses);
    }

    if($self->{'Rearray_History'}) {
        unless($self->{'Rearray_History'}{'purpose'} eq $purpose) {
            $self->{'Error'}="Barcode $barcode has a different Purpose ($purpose) than previously scanned barcode ($self->{Rearray_History}{purpose}";
            return (0, $pses);
        }
        unless($self->{'Rearray_History'}{'org_id'}==$org_id) {
            $self->{'Error'}="Barcode $barcode has a different organism (org_id $org_id) than previously scanned barcode (org_id $self->{Rearray_History}{org_id}";
            return (0, $pses);
        }
        unless($self->{'Rearray_History'}{'seq_vl_id'}==$seq_vl_id) {
            $self->{'Error'}="Barcode $barcode has a different sequencing vector (vl_id $seq_vl_id) than previously scanned barcode (vl_id $self->{Rearray_History}{seq_vl_id}";
            return (0, $pses);
        }
    } else {
        $self->{'Rearray_History'}={purpose   => $purpose,
                                    org_id    => $org_id,
                                    seq_vl_id => $seq_vl_id};
    }

    return ($result, $pses);
}


sub CheckIfUsedAsRearrayOutput { #rearray version
    
    my ($self, $barcode) = @_;
    
    my $desc = $self -> CheckIfUsed($barcode, 'out');
    return if(!$desc);
    delete $self->{'Rearray_History'};
    return $desc;
    
} #CheckIfUsedAsOutput


##########################################################
# Log a transfer from 384 to 96 subclone locations event #
##########################################################
sub Trans96To384 {

    my ($self, $barcode, $pre_pse_id, $new_pse_id, $sec_id) = @_;

    my @psebarcodes = GSC::PSEBarcode->get(pse_id => $pre_pse_id, barcode => $barcode, direction => 'in');
    if(@psebarcodes <= 0) {
      $self->{'Error'} = "No barcode $barcode for the pse $pre_pse_id found!\n";
      return;
    }
    my @dnapses = GSC::DNAPSE->get(pse_id => $pre_pse_id);
    
    # get pt_id from 96 well plate
    my $lt = GSC::LocationType->get(location_type => '384 well plate');
    return 0 if(! $lt);
   
    my $s = GSC::Sector->get(sec_id => $sec_id);
    return 0 if(! $s);

    foreach my $dnapse (@dnapses) {
        my $dl = GSC::DNALocation->get(dl_id => $dnapse->dl_id);
	my ($well_384) = &ConvertWell::To384($dl->location_name, $s->sector_name);
        my $dl384 = GSC::DNALocation->get(location_name => $well_384, sec_id => $s->sec_id, location_type => $lt->location_type);
	return 0 if(! $dl384);
        return 0 if(! GSC::DNAPSE->create(dna_id => $dnapse->dna_id, pse_id => $new_pse_id, dl_id => $dl384->dl_id));
    }   
    return 1;

} #Trans96To384



sub Sequence_1_2_384 {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
    
    my ($sql);
    
    my $pse_ids = [];
    my $status = 'inprogress';
    my $update_status = 'completed';
    my $update_result = 'successful';

    my $reagent_info = $self->GetReagentInfo($options->{'Machine'}, 'plasmid');
    my $dye_chem_id_fwd = $reagent_info->{'FwdDyeChemId'};
    my $dye_chem_id_rev = $reagent_info->{'RevDyeChemId'};
    my $primer_id_fwd = $reagent_info->{'FwdPrimerId'};
    my $primer_id_rev = $reagent_info->{'RevPrimerId'};
    my $enz_id_fwd = $reagent_info->{'FwdEnzId'};
    my $enz_id_rev = $reagent_info->{'RevEnzId'};
    my $reagent_fwd = $reagent_info->{'ReagentNameFwd'};
    my $reagent_rev = $reagent_info->{'ReagentNameRev'};
    my $fwd_barcode = $reagent_info->{'ReagentBarcodeFwd'};
    my $rev_barcode= $reagent_info->{'ReagentBarcodeRev'};

    my $GetSubIdPlIdFromSubclonePse = LoadSql($self->{'dbh'}, qq/select  distinct dna_id, location_name, dl.dl_id  
                                                   from pse_barcodes pbx 
                                                   join dna_pse dp on dp.pse_id = pbx.pse_pse_id
                                                   join dna_location dl on dl.dl_id = dp.dl_id 
                                                   where 
                                                   pbx.bs_barcode = ? and
                                                   dp.pse_id  = ?/, 'ListOfList');
 
    my @sectors= qw(a1 a2 b1 b2);

    my $pt_id = $self ->  Process('GetPlateTypeId', 384);
    return 0 if($pt_id == 0);
    
    for my $i (0 .. $#{$bars_in})
    {
        if($bars_in->[$i] !~ /^empty/)
        {
            my $result = $self -> ComparePrimerReagentToAvailVector($reagent_fwd, $bars_in->[$i]);
            return 0 if(!$result);
            
            $result = $self -> ComparePrimerReagentToAvailVector($reagent_rev, $bars_in->[$i]);
            return 0 if(!$result);
            
            my  $pre_pse_ids = $self ->  Process('GetPrePseForBarcode', $bars_in->[$i], 'out', $status, $ps_id);
            return ($self->GetCoreError) if(!$pre_pse_ids);
            
            foreach my $pre_pse_id (@$pre_pse_ids)
            {
                $result = $self ->  Process('UpdatePse', 'completed', 'successful', $pre_pse_id);
                return 0 if($result == 0);
                
                my ($sec_id_fwd) = $self->{'dbh'} -> selectrow_array(qq/select distinct sec_id from dna_location dl, dna_pse dp where dl.dl_id = dp.dl_id
                                                                        and dp.pse_id = '$pre_pse_id'/);
                return ($self->GetCoreError) if(!$sec_id_fwd);
                
                my $sec_id_rev = $sec_id_fwd;
                
                
                my $new_pse_id_fwd = $self-> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[$i], [$bars_out->[0]], $emp_id);
                return 0 if ($new_pse_id_fwd == 0);
                
                
#                $result = $self ->createSeqDNA($bars_in->[$i], $pre_pse_id, $dye_chem_id_fwd, $primer_id_fwd, $enz_id_fwd, $pt_id, $sec_id_fwd, $new_pse_id_fwd);
#                return 0 if ($result == 0);
                
                
                my $new_pse_id_rev = $self-> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[$i], [$bars_out->[1]], $emp_id);
                return 0 if ($new_pse_id_rev == 0);
               
#                $result = $self ->createSeqDNA($bars_in->[$i], $pre_pse_id, $dye_chem_id_rev, $primer_id_rev, $enz_id_rev, $pt_id, $sec_id_rev, $new_pse_id_rev);
#                return 0 if ($result == 0);
                
                
 

                my $lol =  $GetSubIdPlIdFromSubclonePse -> xSql($bars_in->[$i], $pre_pse_id);
                my @fwd_dnas;
                my @rev_dnas;

                foreach my $row (@{$lol}) {
                    my $dna_id = $row->[0];
                    my $well_384 = $row->[1];
                    my $dl_id = $row->[2];
                
                    push(@fwd_dnas, [pri_id => $primer_id_fwd, 
                                     dc_id => $dye_chem_id_fwd,
                                     enz_id => $enz_id_fwd,
                                     parent_dna_id => $dna_id,
                                     pse_id => $new_pse_id_fwd,
                                     dl_id => $dl_id]);

                    push(@rev_dnas, [pri_id => $primer_id_rev, 
                                     dc_id => $dye_chem_id_rev,
                                     enz_id => $enz_id_rev,
                                     parent_dna_id => $dna_id,
                                     pse_id => $new_pse_id_rev,
                                     dl_id => $dl_id]);
                    
                    
                }                
                
                my @created_fwd_dnas = GSC::SeqDNA->bulk_create(\@fwd_dnas);
                unless(@created_fwd_dnas == 96) {
                    $self->{'Error'} = "SeqSql -> Failed bulk create.";
                    return 0;
                }
                my @created_rev_dnas = GSC::SeqDNA->bulk_create(\@rev_dnas);
                 unless(@created_rev_dnas == 96) {
                    $self->{'Error'} = "SeqSql -> Failed bulk create.";
                    return 0;
                }
                
                
                
                return 0 if(! GSC::ReagentUsedPSE->create(bs_barcode => $fwd_barcode, pse_id => $new_pse_id_fwd));
                return 0 if(! GSC::ReagentUsedPSE->create(bs_barcode => $rev_barcode, pse_id => $new_pse_id_rev));
                
                push(@{$pse_ids}, $new_pse_id_fwd);
                push(@{$pse_ids}, $new_pse_id_rev);
            }
        }
    }

    return $pse_ids;
} #SequenceBiomek1to1_384

sub Sequence_1_2_384_post_confirm {
  my ($self, $pses) = @_;
  #LSF: qsub the confirmation
  if(system("qsub sequence")) {
  
  }
}

sub Sequence_1_2_384_scheduled {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
    
    my ($sql);
    
    my $pse_ids = [];
    my $status = 'inprogress';
    my $update_status = 'completed';
    my $update_result = 'successful';

    my $reagent_info = $self->GetReagentInfo($options->{'Machine'}, 'plasmid');
    my $dye_chem_id_fwd = $reagent_info->{'FwdDyeChemId'};
    my $dye_chem_id_rev = $reagent_info->{'RevDyeChemId'};
    my $primer_id_fwd = $reagent_info->{'FwdPrimerId'};
    my $primer_id_rev = $reagent_info->{'RevPrimerId'};
    my $enz_id_fwd = $reagent_info->{'FwdEnzId'};
    my $enz_id_rev = $reagent_info->{'RevEnzId'};
    my $reagent_fwd = $reagent_info->{'ReagentNameFwd'};
    my $reagent_rev = $reagent_info->{'ReagentNameRev'};
    my $fwd_barcode = $reagent_info->{'ReagentBarcodeFwd'};
    my $rev_barcode= $reagent_info->{'ReagentBarcodeRev'};

    my $GetSubIdPlIdFromSubclonePse = LoadSql($self->{'dbh'}, qq/select  distinct dna_id, location_name, dl.dl_id  
                                                   from pse_barcodes pbx 
                                                   join dna_pse dp on dp.pse_id = pbx.pse_pse_id
                                                   join dna_location dl on dl.dl_id = dp.dl_id 
                                                   where 
                                                   pbx.bs_barcode = ? and
                                                   dp.pse_id  = ?/, 'ListOfList');
 
    my @sectors= qw(a1 a2 b1 b2);

    my $pt_id = $self ->  Process('GetPlateTypeId', 384);
    return 0 if($pt_id == 0);
    
    for my $i (0 .. $#{$bars_in})
    {
        if($bars_in->[$i] !~ /^empty/)
        {
            my $result = $self -> ComparePrimerReagentToAvailVector($reagent_fwd, $bars_in->[$i]);
            return 0 if(!$result);
            
            $result = $self -> ComparePrimerReagentToAvailVector($reagent_rev, $bars_in->[$i]);
            return 0 if(!$result);
            
            my  $pre_pse_ids = $self ->  Process('GetPrePseForBarcode', $bars_in->[$i], 'out', $status, $ps_id);
            return ($self->GetCoreError) if(!$pre_pse_ids);
            
            foreach my $pre_pse_id (@$pre_pse_ids)
            {
                $result = $self ->  Process('UpdatePse', 'completed', 'successful', $pre_pse_id);
                return 0 if($result == 0);
                
                my ($sec_id_fwd) = $self->{'dbh'} -> selectrow_array(qq/select distinct sec_id from dna_location dl, dna_pse dp where dl.dl_id = dp.dl_id
                                                                        and dp.pse_id = '$pre_pse_id'/);
                return ($self->GetCoreError) if(!$sec_id_fwd);
                
                my $sec_id_rev = $sec_id_fwd;
                
                
                my $new_pse_id_fwd = $self-> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[$i], [$bars_out->[0]], $emp_id);
                return 0 if ($new_pse_id_fwd == 0);
                
                
#                $result = $self ->createSeqDNA($bars_in->[$i], $pre_pse_id, $dye_chem_id_fwd, $primer_id_fwd, $enz_id_fwd, $pt_id, $sec_id_fwd, $new_pse_id_fwd);
#                return 0 if ($result == 0);
                
                
                my $new_pse_id_rev = $self-> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[$i], [$bars_out->[1]], $emp_id);
                return 0 if ($new_pse_id_rev == 0);
               
#                $result = $self ->createSeqDNA($bars_in->[$i], $pre_pse_id, $dye_chem_id_rev, $primer_id_rev, $enz_id_rev, $pt_id, $sec_id_rev, $new_pse_id_rev);
#                return 0 if ($result == 0);
                
                
 
=head send this to the qsub script
                my $lol =  $GetSubIdPlIdFromSubclonePse -> xSql($bars_in->[$i], $pre_pse_id);
                my @fwd_dnas;
                my @rev_dnas;

                foreach my $row (@{$lol}) {
                    my $dna_id = $row->[0];
                    my $well_384 = $row->[1];
                    my $dl_id = $row->[2];
                
                    push(@fwd_dnas, [pri_id => $primer_id_fwd, 
                                     dc_id => $dye_chem_id_fwd,
                                     enz_id => $enz_id_fwd,
                                     parent_dna_id => $dna_id,
                                     pse_id => $new_pse_id_fwd,
                                     dl_id => $dl_id]);

                    push(@rev_dnas, [pri_id => $primer_id_rev, 
                                     dc_id => $dye_chem_id_rev,
                                     enz_id => $enz_id_rev,
                                     parent_dna_id => $dna_id,
                                     pse_id => $new_pse_id_rev,
                                     dl_id => $dl_id]);
                    
                    
                }                
                
                my @created_fwd_dnas = GSC::SeqDNA->bulk_create(\@fwd_dnas);
                unless(@created_fwd_dnas == 96) {
                    $self->{'Error'} = "SeqSql -> Failed bulk create.";
                    return 0;
                }
                my @created_rev_dnas = GSC::SeqDNA->bulk_create(\@rev_dnas);
                 unless(@created_rev_dnas == 96) {
                    $self->{'Error'} = "SeqSql -> Failed bulk create.";
                    return 0;
                }
                
=cut                
                
                return 0 if(! GSC::ReagentUsedPSE->create(bs_barcode => $fwd_barcode, pse_id => $new_pse_id_fwd));
                return 0 if(! GSC::ReagentUsedPSE->create(bs_barcode => $rev_barcode, pse_id => $new_pse_id_rev));
                
		#LSF: Changed the PSEs to scheduled status.
		my $np = GSC::PSE->get(pse_id => $new_pse_id_fwd);
		$np->pse_status('scheduled');
		$np = GSC::PSE->get(pse_id => $new_pse_id_rev);
		$np->pse_status('scheduled');
		
                push(@{$pse_ids}, $new_pse_id_fwd);
                push(@{$pse_ids}, $new_pse_id_rev);		
            }
        }
    }

    return $pse_ids;
} #SequenceBiomek1to1_384

sub Sequence_1_1_384 {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
    
    my ($sql);
    
    my $pse_ids = [];
    my $status = 'inprogress';
    my $update_status = 'completed';
    my $update_result = 'successful';

    my $reagent_info = $self->GetReagentInfo($options->{'Machine'}, 'plasmid');
    my $dye_chem_id_fwd = $reagent_info->{'FwdDyeChemId'} || $reagent_info->{'RevDyeChemId'};
    #my $dye_chem_id_rev = $reagent_info->{'RevDyeChemId'};
    my $primer_id_fwd = $reagent_info->{'FwdPrimerId'} || $reagent_info->{'RevPrimerId'};
    #my $primer_id_rev = $reagent_info->{'RevPrimerId'};
    my $enz_id_fwd = $reagent_info->{'FwdEnzId'} || $reagent_info->{'RevEnzId'};
    #my $enz_id_rev = $reagent_info->{'RevEnzId'};
    my $reagent_fwd = $reagent_info->{'ReagentNameFwd'} || $reagent_info->{'ReagentNameRev'};
    #my $reagent_rev = $reagent_info->{'ReagentNameRev'};
    my $fwd_barcode = $reagent_info->{'ReagentBarcodeFwd'} || $reagent_info->{'ReagentBarcodeRev'};
    #my $rev_barcode= $reagent_info->{'ReagentBarcodeRev'};
    
    #LSF: If the the both of the primers do not exist, check the output plate for the primers.
    #if(! ($primer_id_fwd || $primer_id_rev)) {
    if(! ($primer_id_fwd)) {
      my $bout = $bars_out->[0];
      my @pbs = GSC::PSEBarcode->get(barcode => $bout);
      my @pss = GSC::ProcessStep->get(process_step_status => 'active', purpose => 'Sequence', process_to => 'create 384 primer plate');
      my @pses = GSC::PSE->get(ps_id => [ map { $_->ps_id } @pss], pse_id => [ map { $_->pse_id } @pbs]) if(@pss && @pbs);
      if(! @pses) {
        $self->{'Error'} = "$pkg: No pse to find the primer id for [" . $bars_out->[0] . "] or Biomek reagent setup\n";
        return 0;
      }
      #LSF: Get the primer for the forward only.  It only has one direction.
      my @rups = GSC::ReagentUsedPse->get(pse_id => [ map { $_->pse_id } @pses ]);
      my @prns = GSC::PrimerReagentName->get(reagent_name => [map { $_->reagent_name } @rups]) if(@rups);
      if(@prns) {
        $primer_id_fwd = $prns[0]->pri_id;
      } else {
        $self->{'Error'} = "$pkg: No primer id found for [" . $bars_out->[0] . "] or Biomek reagent setup\n";
        return 0;
      }
    }

    my $GetSubIdPlIdFromSubclonePse = LoadSql($self->{'dbh'}, qq/select  distinct dna_id, location_name, dl.dl_id  
                                                   from pse_barcodes pbx 
                                                   join dna_pse dp on dp.pse_id = pbx.pse_pse_id
                                                   join dna_location dl on dl.dl_id = dp.dl_id 
                                                   where 
                                                   pbx.bs_barcode = ? and
                                                   dp.pse_id  = ?/, 'ListOfList');
 
    my @sectors= qw(a1 a2 b1 b2);

    my $pt_id = $self ->  Process('GetPlateTypeId', 384);
    return 0 if($pt_id == 0);
    
    for my $i (0 .. $#{$bars_in})
    {
        if($bars_in->[$i] !~ /^empty/)
        {
            my $result = $self -> ComparePrimerReagentToAvailVector($reagent_fwd, $bars_in->[$i]);
            return 0 if(!$result);
            
            #$result = $self -> ComparePrimerReagentToAvailVector($reagent_rev, $bars_in->[$i]);
            #return 0 if(!$result);
            
            my  $pre_pse_ids = $self ->  Process('GetPrePseForBarcode', $bars_in->[$i], 'out', $status, $ps_id);
            return ($self->GetCoreError) if(!$pre_pse_ids);
            
            foreach my $pre_pse_id (@$pre_pse_ids)
            {
                $result = $self ->  Process('UpdatePse', 'completed', 'successful', $pre_pse_id);
                return 0 if($result == 0);
                
                my ($sec_id_fwd) = $self->{'dbh'} -> selectrow_array(qq/select distinct sec_id from dna_location dl, dna_pse dp where dl.dl_id = dp.dl_id
                                                                        and dp.pse_id = '$pre_pse_id'/);
                return ($self->GetCoreError) if(!$sec_id_fwd);
                
                my $sec_id_rev = $sec_id_fwd;
                
                
                my $new_pse_id_fwd = $self-> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[$i], [$bars_out->[0]], $emp_id);
                return 0 if ($new_pse_id_fwd == 0);
                
                
#                $result = $self ->createSeqDNA($bars_in->[$i], $pre_pse_id, $dye_chem_id_fwd, $primer_id_fwd, $enz_id_fwd, $pt_id, $sec_id_fwd, $new_pse_id_fwd);
#                return 0 if ($result == 0);
                
                
                #my $new_pse_id_rev = $self-> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[$i], [$bars_out->[1]], $emp_id);
                #return 0 if ($new_pse_id_rev == 0);
               
#                $result = $self ->createSeqDNA($bars_in->[$i], $pre_pse_id, $dye_chem_id_rev, $primer_id_rev, $enz_id_rev, $pt_id, $sec_id_rev, $new_pse_id_rev);
#                return 0 if ($result == 0);
                
                
 

                my $lol =  $GetSubIdPlIdFromSubclonePse -> xSql($bars_in->[$i], $pre_pse_id);
                my @fwd_dnas;
                #my @rev_dnas;

                foreach my $row (@{$lol}) {
                    my $dna_id = $row->[0];
                    my $well_384 = $row->[1];
                    my $dl_id = $row->[2];
                
                    push(@fwd_dnas, [pri_id => $primer_id_fwd, 
                                     dc_id => $dye_chem_id_fwd,
                                     enz_id => $enz_id_fwd,
                                     parent_dna_id => $dna_id,
                                     pse_id => $new_pse_id_fwd,
                                     dl_id => $dl_id]);

                    #push(@rev_dnas, [pri_id => $primer_id_rev, 
                    #                 dc_id => $dye_chem_id_rev,
                    #                 enz_id => $enz_id_rev,
                    #                 parent_dna_id => $dna_id,
                    #                 pse_id => $new_pse_id_rev,
                    #                 dl_id => $dl_id]);
                    
                    
                }                
                
                my @created_fwd_dnas = GSC::SeqDNA->bulk_create(\@fwd_dnas);
                unless(@created_fwd_dnas == 96) {
                    $self->{'Error'} = "SeqSql -> Failed bulk create.";
                    return 0;
                }
                #my @created_rev_dnas = GSC::SeqDNA->bulk_create(\@rev_dnas);
                # unless(@created_rev_dnas == 96) {
                #    $self->{'Error'} = "SeqSql -> Failed bulk create.";
                #    return 0;
                #}
                
                
                
                return 0 if(! GSC::ReagentUsedPSE->create(bs_barcode => $fwd_barcode, pse_id => $new_pse_id_fwd));
                #return 0 if(! GSC::ReagentUsedPSE->create(bs_barcode => $rev_barcode, pse_id => $new_pse_id_rev));
                
                push(@{$pse_ids}, $new_pse_id_fwd);
                #push(@{$pse_ids}, $new_pse_id_rev);
            }
        }
    }

    return $pse_ids;
} #SequenceBiomek1to1_384
sub Sequence_1_0_384 {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
    
    my ($sql);
    
    my $pse_ids = [];
    my $status = 'inprogress';
    my $update_status = 'completed';
    my $update_result = 'successful';

    my $reagent_info = $self->GetReagentInfo($options->{'Machine'}, 'plasmid');
    my $dye_chem_id_fwd = $reagent_info->{'FwdDyeChemId'};
    my $dye_chem_id_rev = $reagent_info->{'RevDyeChemId'};
    my $primer_id_fwd = $reagent_info->{'FwdPrimerId'};
    my $primer_id_rev = $reagent_info->{'RevPrimerId'};
    my $enz_id_fwd = $reagent_info->{'FwdEnzId'};
    my $enz_id_rev = $reagent_info->{'RevEnzId'};
    my $reagent_fwd = $reagent_info->{'ReagentNameFwd'};
    my $reagent_rev = $reagent_info->{'ReagentNameRev'};
    my $fwd_barcode = $reagent_info->{'ReagentBarcodeFwd'};
    my $rev_barcode= $reagent_info->{'ReagentBarcodeRev'};
    
    #LSF: If the the both of the primers do not exist, check the output plate for the primers.
    if(! ($primer_id_fwd || $primer_id_rev)) {
      my $bout = $bars_out->[0];
      my @pbs = GSC::PSEBarcode->get(barcode => $bout);
      my @pss = GSC::ProcessStep->get(process_step_status => 'active', purpose => 'Sequence', process_to => 'create 384 primer plate');
      my @pses = GSC::PSE->get(ps_id => [ map { $_->ps_id } @pss], pse_id => [ map { $_->pse_id } @pbs]) if(@pss && @pbs);
      if(! @pses) {
        $self->{'Error'} = "$pkg: No pse to find the primer id for [" . $bars_out->[0] . "] or Biomek reagent setup\n";
        return 0;
      }
      #LSF: Get the primer for the forward only.  It only has one direction.
      my @rups = GSC::ReagentUsedPse->get(pse_id => [ map { $_->pse_id } @pses ]);
      my @prns = GSC::PrimerReagentName->get(reagent_name => [map { $_->reagent_name } @rups]) if(@rups);
      if(@prns) {
        $primer_id_fwd = $prns[0]->pri_id;
      } else {
        $self->{'Error'} = "$pkg: No primer id found for [" . $bars_out->[0] . "] or Biomek reagent setup\n";
        return 0;
      }
    }

    my $GetSubIdPlIdFromSubclonePse = LoadSql($self->{'dbh'}, qq/select  distinct dna_id, location_name, dl.dl_id  
                                                   from pse_barcodes pbx 
                                                   join dna_pse dp on dp.pse_id = pbx.pse_pse_id
                                                   join dna_location dl on dl.dl_id = dp.dl_id 
                                                   where 
                                                   pbx.bs_barcode = ? and
                                                   dp.pse_id  = ?/, 'ListOfList');
 
    my @sectors= qw(a1 a2 b1 b2);

    my $pt_id = $self ->  Process('GetPlateTypeId', 384);
    return 0 if($pt_id == 0);
    
    for my $i (0 .. $#{$bars_in})
    {
        if($bars_in->[$i] !~ /^empty/)
        {
            

            my $pri_id;
            my $dc_id;
            my $enz_id;
            my $brew_barcode;

            if(defined $reagent_fwd) {
                my $result = $self -> ComparePrimerReagentToAvailVector($reagent_fwd, $bars_in->[$i]);
                return 0 if(!$result);
                $dc_id = $reagent_info->{'FwdDyeChemId'};
                $pri_id = $reagent_info->{'FwdPrimerId'};
                $enz_id = $reagent_info->{'FwdEnzId'};
                $brew_barcode = $reagent_info->{'ReagentBarcodeFwd'};
 
              
            }
            elsif(defined $reagent_rev) {
                my $result = $self -> ComparePrimerReagentToAvailVector($reagent_rev, $bars_in->[$i]);
                return 0 if(!$result);
                $dc_id = $reagent_info->{'RevDyeChemId'};
                $pri_id = $reagent_info->{'RevPrimerId'};
                $enz_id = $reagent_info->{'RevEnzId'};
                $brew_barcode = $reagent_info->{'ReagentBarcodeRev'};
            }
            else {

                $self->{'Error'} = 'No defined reagent to compare primer and vector';
                return 0;
            }

            my  $pre_pse_ids = $self ->  Process('GetPrePseForBarcode', $bars_in->[$i], 'in', $status, $ps_id);
            return ($self->GetCoreError) if(!$pre_pse_ids);
            
            foreach my $pre_pse_id (@$pre_pse_ids)
            {
                my $result = $self ->  Process('UpdatePse', 'completed', 'successful', $pre_pse_id);
                return 0 if($result == 0);
                
                my ($sec_id_fwd) = $self->{'dbh'} -> selectrow_array(qq/select distinct sec_id from dna_location dl, dna_pse dp where dl.dl_id = dp.dl_id
                                                                        and dp.pse_id = '$pre_pse_id'/);
                return ($self->GetCoreError) if(!$sec_id_fwd);
                
                my $sec_id_rev = $sec_id_fwd;
                
                #LSF: There is no brcode out.
                my $new_pse_id_fwd = $self-> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[$i], $bars_out, $emp_id);
                return 0 if ($new_pse_id_fwd == 0);

                my $lol =  $GetSubIdPlIdFromSubclonePse -> xSql($bars_in->[$i], $pre_pse_id);
                my @fwd_dnas;
                #my @rev_dnas;

                foreach my $row (@{$lol}) {
                    my $dna_id = $row->[0];
                    my $well_384 = $row->[1];
                    my $dl_id = $row->[2];
                
                    push(@fwd_dnas, [pri_id => $pri_id, 
                                     dc_id => $dc_id,
                                     enz_id => $enz_id,
                                     parent_dna_id => $dna_id,
                                     pse_id => $new_pse_id_fwd,
                                     dl_id => $dl_id]);

                }                
                
                my @created_fwd_dnas = GSC::SeqDNA->bulk_create(\@fwd_dnas);
                unless(@created_fwd_dnas == 96) {
                    $self->{'Error'} = "SeqSql -> Failed bulk create.";
                    return 0;
                }
                return 0 if(! GSC::ReagentUsedPSE->create(bs_barcode => $brew_barcode, pse_id => $new_pse_id_fwd));
                
                push(@{$pse_ids}, $new_pse_id_fwd);
            }
        }
    }

    return $pse_ids;
} #SequenceBiomek1to1_384

sub Sequence_1_0_384_scheduled {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;    
    my $pse_ids = [];
    my $status = 'inprogress';
    my $update_status = 'completed';
    my $update_result = 'successful';

    my $reagent_premix = $options->{'Reagents'}->{'Brew'}->{'barcode'};
    my $dye_chem_id   = $self->GetFwdDyeChemId($reagent_premix) || $self->GetRevDyeChemId($reagent_premix);
    my $primer_id     = $self->GetFwdPrimerId($reagent_premix)  || $self->GetRevPrimerId($reagent_premix);
    my $enz_id        = $self->GetFwdEnzId($reagent_premix)  || $self->GetRevEnzId($reagent_premix);


    if(@{$pre_pse_ids} > 4) {
        $self->{'Error'} = "$pkg: To many prior pse_id founds\n";
        return 0;
    }

    #LSF: If the the both of the primers do not exist, check the output plate for the primers.
    if(! $primer_id) {
      my $bout = $bars_out->[0];
      my @pbs = GSC::PSEBarcode->get(barcode => $bout);
      my @pss = GSC::ProcessStep->get(process_step_status => 'active', purpose => 'Sequence', process_to => 'create 384 primer plate');
      my @pses = GSC::PSE->get(ps_id => [ map { $_->ps_id } @pss], pse_id => [ map { $_->pse_id } @pbs]) if(@pss && @pbs);
      if(! @pses) {
        $self->{'Error'} = "$pkg: No pse to find the primer id for [" . $bars_out->[0] . "] or Biomek reagent setup\n";
        return 0;
      }
      #LSF: Get the primer for the forward only.  It only has one direction.
      my @rups = GSC::ReagentUsedPse->get(pse_id => [ map { $_->pse_id } @pses ]);
      my @prns = GSC::PrimerReagentName->get(reagent_name => [map { $_->reagent_name } @rups]) if(@rups);
      if(@prns) {
        $primer_id = $prns[0]->pri_id;
      } else {
        $self->{'Error'} = "$pkg: No primer id found for [" . $bars_out->[0] . "] or Biomek reagent setup\n";
        return 0;
      }
    }
						   
    my $ri = GSC::ReagentInformation->get(barcode => $reagent_premix);
    my $reagent = $ri->reagent_name if($ri);

    my $pt_id = $self ->  Process('GetPlateTypeId', 384);
    return 0 if($pt_id == 0);
    
    my $primer_direction = GSC::Primer->get(pri_id => $primer_id)->primer_direction;
    unless($primer_direction) {
        $self->{'Error'} = 'Could not get primer direction.';
        return 0;
    }
    
    for my $barcode (@$bars_in) {
        
        my ($barcode_direction) = App::DB::dbh->selectrow_array(qq/select distinct pdo.data_value 
                                                              from
                                                              pse_data_outputs pdo 
                                                              join pse_barcodes pb on pb.pse_pse_id = pdo.pse_pse_id
                                                              where
                                                              pb.direction = 'out'
                                                              and pb.bs_barcode = '$barcode'/);

        unless($barcode_direction eq $primer_direction) {
            $self->{'Error'} = 'Primer direction does not match the barcode plate direction assigned';
            return 0;
        }


        if($barcode !~ /^empty/) {
            if(defined $reagent) {
                return 0 if(! $self -> ComparePrimerReagentToAvailVector($reagent, $barcode));
            } else {
                $self->{'Error'} = 'No defined reagent to compare primer and vector';
                return 0;
            }

            my  $pre_pse_ids = $self ->  Process('GetPrePseForBarcode', $barcode, 'in', $status, $ps_id);
            return ($self->GetCoreError) if(!$pre_pse_ids);
            
            foreach my $pre_pse_id (@$pre_pse_ids) {
                my $result = $self ->  Process('UpdatePse', 'completed', 'successful', $pre_pse_id);
                return 0 if($result == 0);               
                my $sec_id = $self->{'dbh'} -> selectrow_array(qq/select distinct sec_id from dna_location dl, dna_pse dp where dl.dl_id = dp.dl_id
                                                                        and dp.pse_id = '$pre_pse_id'/);
                return ($self->GetCoreError) if(!$sec_id);
                
                #LSF: There is no brcode out.
                my $new_pse_id = $self-> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $barcode, $bars_out, $emp_id);
                return 0 if(! $new_pse_id);
                #return 0 if(! GSC::ReagentUsedPSE->create(bs_barcode => $reagent_premix, pse_id => $new_pse_id));
                
		#LSF: Changed the PSEs to scheduled status.
		my $np = GSC::PSE->get(pse_id => $new_pse_id);
		$np->pse_status('scheduled');


                


                push(@{$pse_ids}, $new_pse_id);
            }
        }
    }

    return $pse_ids;
} #Sequence_1_0_384_scheduled

sub create_384_primer_plate {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

    my $primer_barcode = $options->{'Reagents'}->{'Primer'}->{'barcode'};
    my $new_pse_id = $self-> xOneToManyProcess($ps_id, undef, undef, undef, undef, [$bars_in->[0]], $emp_id);
    return 0 if(! $new_pse_id);
    return [$new_pse_id];
}

sub create_sequenced_dna_384 {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
    
    my ($sql);
    
    my $pse_ids = [];
    my $status = 'inprogress';
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $reagent_premix = $options->{'Reagents'}->{'Premix'}->{'barcode'};
    my $reagent_fwd_primer = $options->{'Reagents'}->{'FWD Primer'}->{'barcode'};
    my $reagent_rev_primer = $options->{'Reagents'}->{'REV Primer'}->{'barcode'};
    
    #my $buffer = $self -> GetEnzIdFromReagent($reagent_premix);
    #my $enzyme1 = $self -> GetEnzIdFromReagent($reagent_enzyme1);
    #my $enzyme2 = $self -> GetEnzIdFromReagent($reagent_enzyme2);

    my $dye_chem_id_fwd = $self->GetFwdDyeChemId($reagent_premix);
    my $dye_chem_id_rev = $self->GetRevDyeChemId($reagent_premix);
    my $primer_id_fwd = $self->GetFwdPrimerId($reagent_fwd_primer);
    my $primer_id_rev = $self->GetRevPrimerId($reagent_rev_primer);
    my $enz_id_fwd = $self->GetFwdEnzId($reagent_fwd_primer);
    my $enz_id_rev = $self->GetRevEnzId($reagent_rev_primer);
    my $ri_fwd = GSC::ReagentInformation->get(barcode => $reagent_fwd_primer);
    my $ri_rev = GSC::ReagentInformation->get(barcode => $reagent_rev_primer);
    my $reagent_fwd = $ri_fwd->reagent_name if($ri_fwd);
    my $reagent_rev = $ri_rev->reagent_name if($ri_rev);
    my $fwd_barcode = $reagent_fwd_primer;
    my $rev_barcode = $reagent_rev_primer;

=cut
    my $reagent_info = $self->GetReagentInfo($options->{'Machine'}, 'plasmid');
    my $dye_chem_id_fwd = $reagent_info->{'FwdDyeChemId'};
    my $dye_chem_id_rev = $reagent_info->{'RevDyeChemId'};
    my $primer_id_fwd = $reagent_info->{'FwdPrimerId'};
    my $primer_id_rev = $reagent_info->{'RevPrimerId'};
    my $enz_id_fwd = $reagent_info->{'FwdEnzId'};
    my $enz_id_rev = $reagent_info->{'RevEnzId'};
    my $reagent_fwd = $reagent_info->{'ReagentNameFwd'};
    my $reagent_rev = $reagent_info->{'ReagentNameRev'};
    my $fwd_barcode = $reagent_info->{'ReagentBarcodeFwd'};
    my $rev_barcode= $reagent_info->{'ReagentBarcodeRev'};
=cut

    my $GetSubIdPlIdFromSubclonePse = LoadSql($self->{'dbh'}, qq/select  distinct dna_id, location_name, dl.dl_id  
                                                   from pse_barcodes pbx 
                                                   join dna_pse dp on dp.pse_id = pbx.pse_pse_id
                                                   join dna_location dl on dl.dl_id = dp.dl_id 
                                                   where 
                                                   pbx.bs_barcode = ? and
                                                   dp.pse_id  = ?/, 'ListOfList');
 
    my @sectors= qw(a1 a2 b1 b2);

    my $pt_id = $self ->  Process('GetPlateTypeId', 384);
    return 0 if($pt_id == 0);
    
    for my $i (0 .. $#{$bars_in})
    {
        if($bars_in->[$i] !~ /^empty/)
        {
            my $result = $self -> ComparePrimerReagentToAvailVector($reagent_fwd, $bars_in->[$i]);
            return 0 if(!$result);
            
            $result = $self -> ComparePrimerReagentToAvailVector($reagent_rev, $bars_in->[$i]);
            return 0 if(!$result);
            
            my  $pre_pse_ids = $self ->  Process('GetPrePseForBarcode', $bars_in->[$i], 'out', $status, $ps_id);
            return ($self->GetCoreError) if(!$pre_pse_ids);
            
            foreach my $pre_pse_id (@$pre_pse_ids)
            {
                $result = $self ->  Process('UpdatePse', 'completed', 'successful', $pre_pse_id);
                return 0 if($result == 0);
                
                my ($sec_id_fwd) = $self->{'dbh'} -> selectrow_array(qq/select distinct sec_id from dna_location dl, dna_pse dp where dl.dl_id = dp.dl_id
                                                                        and dp.pse_id = '$pre_pse_id'/);
                return ($self->GetCoreError) if(!$sec_id_fwd);
                
                my $sec_id_rev = $sec_id_fwd;
                
                
                my $new_pse_id_fwd = $self-> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[$i], [$bars_out->[0]], $emp_id);
                return 0 if ($new_pse_id_fwd == 0);
                
                
#                $result = $self ->createSeqDNA($bars_in->[$i], $pre_pse_id, $dye_chem_id_fwd, $primer_id_fwd, $enz_id_fwd, $pt_id, $sec_id_fwd, $new_pse_id_fwd);
#                return 0 if ($result == 0);
                
                
                my $new_pse_id_rev = $self-> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[$i], [$bars_out->[1]], $emp_id);
                return 0 if ($new_pse_id_rev == 0);
               
#                $result = $self ->createSeqDNA($bars_in->[$i], $pre_pse_id, $dye_chem_id_rev, $primer_id_rev, $enz_id_rev, $pt_id, $sec_id_rev, $new_pse_id_rev);
#                return 0 if ($result == 0);
                
                
 

                my $lol =  $GetSubIdPlIdFromSubclonePse -> xSql($bars_in->[$i], $pre_pse_id);
                my @fwd_dnas;
                my @rev_dnas;

                foreach my $row (@{$lol}) {
                    my $dna_id = $row->[0];
                    my $well_384 = $row->[1];
                    my $dl_id = $row->[2];
                
                    push(@fwd_dnas, [pri_id => $primer_id_fwd, 
                                     dc_id => $dye_chem_id_fwd,
                                     enz_id => $enz_id_fwd,
                                     parent_dna_id => $dna_id,
                                     pse_id => $new_pse_id_fwd,
                                     dl_id => $dl_id]);

                    push(@rev_dnas, [pri_id => $primer_id_rev, 
                                     dc_id => $dye_chem_id_rev,
                                     enz_id => $enz_id_rev,
                                     parent_dna_id => $dna_id,
                                     pse_id => $new_pse_id_rev,
                                     dl_id => $dl_id]);
                    
                    
                }                
                
                my @created_fwd_dnas = GSC::SeqDNA->bulk_create(\@fwd_dnas);
                unless(@created_fwd_dnas == 96) {
                    $self->{'Error'} = "SeqSql -> Failed bulk create.";
                    return 0;
                }
                my @created_rev_dnas = GSC::SeqDNA->bulk_create(\@rev_dnas);
                 unless(@created_rev_dnas == 96) {
                    $self->{'Error'} = "SeqSql -> Failed bulk create.";
                    return 0;
                }
                
                
                
                return 0 if(! GSC::ReagentUsedPSE->create(bs_barcode => $fwd_barcode, pse_id => $new_pse_id_fwd));
                return 0 if(! GSC::ReagentUsedPSE->create(bs_barcode => $rev_barcode, pse_id => $new_pse_id_rev));
                
                push(@{$pse_ids}, $new_pse_id_fwd);
                push(@{$pse_ids}, $new_pse_id_rev);
            }
        }
    }

    return $pse_ids;
} #SequenceBiomek1to1_384


sub createSeqDNA {
    my ($self, $barcode, $pre_pse_id, $dye_chem_id, $pri_id, $enz_id, $pt_id, $sec_id, $new_pse_id) = @_;

    my @dnapses = GSC::DNAPSE->get(pse_id => $pre_pse_id);


    for my $dnapse (@dnapses) {
        
        # create SeqDNA
        my $seqdna = GSC::SeqDNA->create(
                    parent_dna_id   => $dnapse->dna_id, 
                    pse_id          => $new_pse_id, 
                    dl_id           => $dnapse->dl_id,
                    dc_id           => $dye_chem_id,
                    pri_id          => $pri_id,
                    enz_id          => $enz_id,
        );
        return 0 if(! $seqdna);
  }
  return 1;
}

sub Claim384OnePseToFour {
    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options) = @_;


    my $pse_ids = [];
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $i = 0;

    my ($lib, $ref_pses) = $self -> GetAvailBarcodeOutInprogress($bars_in->[0], $ps_id);
    
    my $pre_pse_id = $ref_pses->[0];
    
    my @dp_rep = GSC::Sector->get(sql=>qq/select distinct sec.* from sectors sec
				  join dna_location dl on dl.sec_id = sec.sec_id
				  join dna_pse dp on dl.dl_id = dp.dl_id
				  where dp.pse_id = $pre_pse_id/);

    my @filled_sectors = map {$_->sector_name} @dp_rep;
    
    foreach my $sector (@filled_sectors) {
		    
	my ($new_pse_id) = $self-> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], [], $emp_id);
	
	my @dp = GSC::DNAPSE->get(sql=>qq/SELECT dp.* FROM dna_pse dp
				  JOIN dna_location dl ON dl.dl_id = dp.dl_id
				  JOIN sectors sec on dl.sec_id = sec.sec_id
				  WHERE 
				  pse_id = $pre_pse_id AND sector_name = '$sector'/);
	
	foreach my $dp_prev (@dp) {
	    my $dpc = GSC::DNAPSE->create(dna_id=>$dp_prev->dna_id,
				pse_id=>$new_pse_id,
				dl_id=>$dp_prev->dl_id);
				    
	    if (!defined $dpc) {
		$self->{'Error'} = "Unable to create dnapse";
		return 0;
	    }
	}
	push(@{$pse_ids}, $new_pse_id);

    }
    
    return $pse_ids;
}
=head1 create

Create the sequenced dna.

=cut
sub run_dna_creation {
  my $self = shift;
  my($pse_id) = @_;
  my @pbs = GSC::PSEBarcode->get(pse_id => $pse_id, direction => 'in');
  if(! @pbs) {
    die "Do not have any in barcode link to the $pse_id!\n";
  }
  my($rbarcode, $pri_id, $dc_id, $enz_id) = $self->get_reagent_information($pse_id);
  if(! $pri_id && $dc_id && $enz_id) {
    die "Cannot find the reagent information for the PSE_ID [$pse_id]!\n";
  }
  my $barcode = $pbs[0]->barcode;
  #LSF: Find the prior pse id.
  my $pse = GSC::PSE->get(pse_id => $pse_id);
  my $prior_pse_id = $pse->prior_pse_id;
  if(! $pse->prior_pse_id) {
    my $tpp_pse = GSC::TppPSE->get(pse_id => $pse_id, barcode => $barcode);
    if(! $tpp_pse) {
      die "Cannot find the prior pse id for pse_id $pse_id!\n";
    } 
    $prior_pse_id = $tpp_pse->prior_pse_id;
  }
  my @dps = $self->get_dna($barcode, $prior_pse_id);
  my @dnas;
  foreach my $dp (@dps) {
    push(@dnas, [pri_id => $pri_id, 
                 dc_id => $dc_id,
                 enz_id => $enz_id,
                 parent_dna_id => $dp->dna_id,
                 pse_id => $pse_id,
                 dl_id => $dp->dl_id]);
  }               

  my @created_dnas = GSC::SeqDNA->bulk_create(\@dnas);
  unless(scalar @created_dnas == scalar @dnas) {
    die "$0 -> Failed bulk create.";
  }
}

=head1 get_dna

Get the dna pse with the barcode and pse_id as input.

The barcode is to use to check with the pse_id to make sure they are in proper state.

=cut

sub get_dna {
  my $self = shift;
  my($barcode, $pse_id) = @_;
  #LSF: This is only to check to make sure the pse_id is tie to the right barcode.
  return unless(GSC::PSEBarcode->get(barcode => $barcode, pse_id => $pse_id));
  return GSC::DNAPSE->get(pse_id => $pse_id);
}

=head1 get_reagent_information

Get the reagent information with the pse_id.

=cut
sub get_reagent_information {
  my $self = shift;
  my($pse_id) = @_;
  my @rups = GSC::ReagentUsedPSE->get(pse_id => $pse_id);
  if(@rups != 1) {
    die "Should have only one reagent barcode but found [" . scalar @rups . "]\n";
  }
  my $barcode = $rups[0]->bs_barcode;
  my $ri = GSC::ReagentInformation->get(barcode => $barcode);
  my $direction = $ri->reagent_name =~ /FWD/ ? "forward" : "reverse";
  my @prns    = GSC::PrimerReagentName->get(reagent_name => $ri->reagent_name);
  my @pris = GSC::Primer->get(pri_id => \@prns, primer_direction => $direction);
  return if(! @pris);
  my @dcrns   = GSC::DyeChemistryReagentName->get(reagent_name => $ri->reagent_name);
  return if(! @prns && @dcrns);
  my $dc_id = $dcrns[0]->dc_id;
  my @erns = GSC::EnzymeReagentName->get(reagent_name => $ri->reagent_name);
  return if(! @prns && @erns);
  my $enz_id = $erns[0]->enz_id;
  my $pri_id = $prns[0]->pri_id;
  return ($barcode, $pri_id, $dc_id, $enz_id);
}

1;

# $Header$
