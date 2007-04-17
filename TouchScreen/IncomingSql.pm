# -*-Perl-*-

##############################################
# Copyright (C) 2003 Craig S. Pohl
# WASHINGTON University, St. Louis
# All Rights Reserved.
##############################################

package TouchScreen::IncomingSql;

use strict;
use ConvertWell ':all';
use DbAss;

#############################################################
# Production sql code package
#############################################################

require Exporter;

our @ISA = qw(Exporter TouchScreen::CoreSql);

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
 
     
    return $self;
} #new


sub GetAndCheckBarcodeOutInprogress{
    #--- check the output description for the plate type
    my ($self, $barcode, $ps_id) = @_;
    my $ps = GSC::ProcessStep->get(ps_id => $ps_id);
    my $od = $ps->output_device;
    my $bc = GSC::Barcode->get($barcode);
    
    unless($ps && $od && $bc){
	$self->{'Error'} = "failed to get core information from barcode $barcode and ps_id $ps_id";
	return 0;
    }
    unless($bc->container_type_isa($od)){
	$self->{'Error'} = "The barcode $barcode is not a $od, and that is required (it is a ".$bc->container_type.")";
	return 0;
    }
    return $self->GetAvailBarcodeOutInprogress($barcode, $ps_id);
}

sub GetAvailBarcodeInInprogress384 {

    my ($self, $barcode, $ps_id) = @_;
  
    my $bar = GSC::Barcode->get(barcode => $barcode);
    return unless($bar);
    
    my @dp = $bar->get_dna;
    unless(scalar(@dp) == 384) {
        $self->{'Error'} = 'The source barcode does not have 96 dna';
        return;
    }

    return $self->GetAvailBarcodeInInprogress($barcode, $ps_id);
}

sub GetAvailBarcodeInInprogress96 {

    my ($self, $barcode, $ps_id) = @_;
  
    my $bar = GSC::Barcode->get(barcode => $barcode);
    return unless($bar);
    
    my @dp = $bar->get_dna;
    unless(scalar(@dp) == 96) {
        $self->{'Error'} = 'The source barcode does not have 96 dna';
        return;
    }

    return $self->GetAvailBarcodeInInprogress($barcode, $ps_id);
}
################################################################################
#                                                                              #
#                               Input verification subroutines                 #
#                                                                              #
################################################################################

##########################################
##########################################
sub RearrayDNA384to4_96 {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
 
    my $pse_ids = [];
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $i=0;


   
    



    foreach my $quad  ('a1', 'a2', 'b1', 'b2') {
        
	my ($new_pse_id) = $self->xOneToManyProcess($ps_id, $pre_pse_ids->[0], $update_status, $update_result, $bars_in->[0], [$bars_out->[$i]], $emp_id);
        
        my $dna_pse = App::DB->dbh->selectall_arrayref(qq/select distinct dna_id, location_name 
                                                       from
                                                       pse_barcodes pb
                                                       join dna_pse dp on dp.pse_id = pb.pse_pse_id
                                                       join dna_location dl on dl.dl_id = dp.dl_id
                                                       join sectors s on s.sec_id = dl.sec_id
                                                       where
                                                       pb.bs_barcode = '$bars_in->[0]'
                                                       and pb.direction  = 'out'
                                                       and s.sector_name = '$quad'/);
        foreach my $row (@$dna_pse) {
            
            my $dna_id = $row->[0];
            my $well_384 = $row->[1];
            
            my ($well_96, $sector) = &ConvertWell::To96($well_384);
            
            my $dl = GSC::DNALocation->get(location_type => '96 well plate',
                                           location_name => $well_96,
                                           sec_id => 1);
            return unless($dl);
            
            return unless(GSC::DNAPSE->create(dna_id => $dna_id,
                                              dl_id => $dl,
                                              pse_id => $new_pse_id));
            
            
        }
        
        $i++;
        push(@$pse_ids, $new_pse_id);
    }
    
    
    
    return $pse_ids;

} #Inoculate384to96


sub PrepIncomingArchive {
    
    my ($self, $ps_id, $bars_in, $bar_out, $emp_id, $options, $pre_pse_ids) = @_;
 
    my $pse_ids = [];
    my $update_status = 'completed';
    my $update_result = 'successful';

    my $group = $self-> Process('GetGroupForPsId', $ps_id);
    return ($self->GetCoreError) if($group eq '0');
    
    my $pso = GSC::ProcessStepOutput->get(ps_id => $ps_id, 
                                          output_description => 'sequence direction');
    
    my $i = 0;  
    my $pre_pse_sth = App::DB->dbh->prepare(qq/select distinct s.sector_name, pse.pse_id  from 
					    process_steps ps1
					    join process_steps ps2 on ps2.pro_process_to = ps1.pro_process
					    join process_step_executions pse on pse.ps_ps_id = ps2.ps_id
					    join pse_barcodes pb on pb.pse_pse_id = pse.pse_id
					    join dna_pse dp on dp.pse_id = pse.prior_pse_id
					    join dna_location dl on dl.dl_id = dp.dl_id
					    join sectors s on s.sec_id = dl.sec_id
					    where
					    ps1.ps_id = $ps_id
					    and pb.bs_barcode = '$bars_in->[0]'
					    and s.sector_name IN ('a1', 'a2', 'b1', 'b2')
					    and pb.direction = 'in'
					    and pse.psesta_pse_status = 'inprogress'/);    
    my %quad_pre_pse_ids=();
    $pre_pse_sth->execute;
    while(my ($quad, $pre_pse_id)=$pre_pse_sth->fetchrow_array) {
        $quad_pre_pse_ids{$quad}=$pre_pse_id;
    }

    #-----  try a different approach
    unless(%quad_pre_pse_ids){
	my $pre_pse_sth = App::DB->dbh->prepare(qq/select distinct s.sector_name, pse.pse_id from 
						process_steps ps1
						join process_steps ps2 on ps2.pro_process_to = ps1.pro_process
						join process_step_executions pse on pse.ps_ps_id = ps2.ps_id
						join pse_barcodes pb on pb.pse_pse_id = pse.pse_id
						join pse_barcodes bar_source on pb.bs_barcode = bar_source.bs_barcode
						     AND bar_source.direction = 'out'
						join dna_pse dp on bar_source.pse_pse_id = dp.pse_id
						join dna_location dl on dl.dl_id = dp.dl_id
						join sectors s on s.sec_id = dl.sec_id
						where
						ps1.ps_id = $ps_id
						and pb.bs_barcode = '$bars_in->[0]'
						and s.sector_name IN ('a1', 'a2', 'b1', 'b2')
						and pb.direction = 'in'
						and pse.psesta_pse_status = 'inprogress'/);    
	
	$pre_pse_sth->execute;
	while(my ($quad, $pre_pse_id)=$pre_pse_sth->fetchrow_array) {
	    $quad_pre_pse_ids{$quad}=$pre_pse_id;
	}
    }
    
    foreach my $quad  ('a1', 'a2', 'b1', 'b2') {

        my $pre_pse_id=$quad_pre_pse_ids{$quad};
	
        unless($pre_pse_id) {

            $self->{'Error'} = "Could not derive the prior pse for barcode.";
            return;
        }
        
        my ($fnew_pse_id) = $self-> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], [$bar_out->[0]], $emp_id);
        return ($self->GetCoreError) if(!$fnew_pse_id);
        
        unless(GSC::PSEDataOutput->create(pse_id => $fnew_pse_id,
                                         pso_id => $pso,
                                         data_value => 'forward')) {
            $self->{'Error'} = "Could not create the forward pse data output";
            return 0;
        };


	my ($rnew_pse_id) = $self-> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], [$bar_out->[1]], $emp_id);
	return ($self->GetCoreError) if(!$rnew_pse_id);
        unless(GSC::PSEDataOutput->create(pse_id => $rnew_pse_id,
                                         pso_id => $pso,
                                         data_value => 'reverse')) {
            $self->{'Error'} = "Could not create the forward pse data output";
            return 0;
        };
        
        my $dna_pse = App::DB->dbh->selectall_arrayref(qq/select distinct dna_id, dp.dl_id 
                                                       from
                                                       pse_barcodes pb
                                                       join dna_pse dp on dp.pse_id = pb.pse_pse_id
                                                       join dna_location dl on dl.dl_id = dp.dl_id
                                                       join sectors s on s.sec_id = dl.sec_id
                                                       where
                                                       pb.bs_barcode = '$bars_in->[0]'
                                                       and pb.direction  = 'out'
                                                       and s.sector_name = '$quad'/);
        
	unless($dna_pse) {
            $self->{'Error'} = "Could not find the dna_pses!\n";
            return 0;	
	}
        
	foreach my $dp (@$dna_pse) {
            
            unless(GSC::DNAPSE->create(dl_id => $dp->[1], 
                                       pse_id => $fnew_pse_id,
                                       dna_id => $dp->[0])) {
                $self->{'Error'} = "Could not create the dna_pse for dl_id [" . $dp->[1] . "] pse_id [" . $fnew_pse_id . "] dna_id [" . $dp->[0] . "].";
                return 0;
            }
            unless(GSC::DNAPSE->create(dl_id => $dp->[1], 
                                       pse_id => $rnew_pse_id,
                                       dna_id => $dp->[0])) {
                $self->{'Error'} = "Could not create the dna_pse for dl_id [" . $dp->[1] . "] pse_id [" . $rnew_pse_id . "] dna_id [" . $dp->[0] . "].";
                return 0;
            }
	}
	
	push(@{$pse_ids}, $fnew_pse_id);
	push(@{$pse_ids}, $rnew_pse_id);

        $i++;
    }

    return $pse_ids;
} #ClaimArchive




1;

# $Header$
