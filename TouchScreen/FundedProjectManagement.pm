# -*-Perl-*-

################################################################################
#                                                                              #
# Copyright (C) 2003 Shin F. Leong                                             #
# WASHINGTON University, St. Louis                                             #
# All Rights Reserved.                                                         #
#                                                                              #
################################################################################

package TouchScreen::FundedProjectManagement;

use strict;
use ConvertWell ':all';
use DBI;
use DbAss;
use TouchScreen::CoreSql;
use TouchScreen::TouchSql;
use BarcodeImage;
use TouchScreen::GelImageLogSheet;
use Data::Dumper;

################################################################################
#                                                                              #
# Production sql code package                                                  #
#                                                                              #
################################################################################

require Exporter;

our @ISA = qw(TouchScreen::CoreSql);

my $pkg = __PACKAGE__;


=head1 new
                                                                              
 Constructor for the class.
 Create a new instance of the FundedProjectManagement code so that you        
 can easily use more than one data base schema                                
                                                                              
=cut

sub new {

    # Input
    my ($class, $dbh, $schema) = @_;
    
    my $self = $class->SUPER::new( $dbh, $schema );
    
    $self->{'ScanSeqInputPlate'} = 'dna';
    
    $self->{'GetAvailableDNAResourceItemsWithOrderBarcode'} = LoadSql($dbh,  qq/select 
      distinct bs.barcode, 
      bs.barcode_description, 
      pse1.pse_id, 
      pse1.psesta_pse_status, 
      dri.dna_resource_item_name
    from 
      dna_resource_item_order drio, 
      dna_resource_item_order_pse dpse, 
      dna_resource_item dri,
      dna_relationship dr, 
      dna_pse dp, 
      dna d, 
      dna_pse dp1, 
      pse_barcodes pb, 
      barcode_sources bs, 
      process_step_executions pse1, 
      process_steps ps 
    where
      drio.drio_id = dpse.drio_id
    and
      dpse.pse_id = dp.pse_id 
    and
      dr.parent_dna_id = dri.dri_id
    and
      dr.parent_dna_id = dp.dna_id 
    and
      dp.pse_id in (select distinct pb.pse_pse_id from pse_barcodes pb where pb.bs_barcode = ? and direction = 'out') 
    and
      dr.dna_id = d.dna_id
    and
      dp1.dna_id = d.dna_id
    and
      dp1.pse_id = pb.pse_pse_id
    and
      pb.bs_barcode = bs.barcode
    and
      dp1.pse_id = pse1.pse_id
    and
      ps.ps_id = pse1.ps_ps_id/, 'ListOfList');
    $self->{'GetAvailableDNAResourceItem'} = LoadSql($dbh,  qq/select 
  distinct pb.bs_barcode, dri.dna_resource_item_name
from
  dna_resource_item dri,
  dna_relationship dr, 
  dna_pse dp, 
  dna d, 
  pse_barcodes pb, 
  barcode_sources bs 
where
   dr.parent_dna_id = dri.dri_id 
and
  dr.dna_id = d.dna_id
and
  dp.dna_id = d.dna_id
and
  dp.pse_id = pb.pse_pse_id
and
  pb.bs_barcode = bs.barcode
and
  pb.bs_barcode = ?/, 'ListOfList');
  $self->{'IsAcceptDNAResourceItemOrderInThisStatus'} = LoadSql($dbh,  qq/select 
    distinct pse.pse_id
  from 
    process_step_executions pse
  where 
     pse.psesta_pse_status = ?
  and
    pse.ps_ps_id in (
      select ps.ps_id from process_steps ps where ps.pro_process_to = 'accept dna resource item order')  
  start with pse.pse_id in (
select 
        pse.pse_id
      from 
        process_step_executions pse 
      where 
        pse.ps_ps_id in (
      select ps.ps_id from process_steps ps where ps.pro_process_to = 'create dna resource item order')
      start with 
        pse.pse_id = ? 
      connect by 
        pse.pse_id = prior pse.prior_pse_id)
  connect by 
    prior pse.pse_id = pse.prior_pse_id/, 'ListOfList');
    
  $self->{'IsAcceptDNAResourceItemOrderInThisStatus_old'} = LoadSql($dbh,  qq/select 
    distinct pse.pse_id
  from 
    process_step_executions pse 
  where 
    pse.psesta_pse_status = ?
  and
    pse.ps_ps_id in (
      select ps.ps_id from process_steps ps where ps.pro_process_to = 'accept dna resource item order')  
  start with pse.pse_id in (
      select 
        pse.pse_id  
      from 
        process_step_executions pse 
      where 
        prior_pse_id = 0 or prior_pse_id = 1 
      start with 
        pse.pse_id = ? 
      connect by 
        pse.pse_id = prior pse.prior_pse_id)
  connect by 
    prior pse.pse_id = pse.prior_pse_id/, 'ListOfList');
 
    $self->{'GetAvailableDNAResourceItem_old'} = LoadSql($dbh,  qq/select 
  distinct dp.dna_id, dp.pse_id, dp.dl_id 
from 
  dna_resource_item_order drio, 
  dna_resource_item_order_pse dpse, 
  pse_barcodes pb, 
  dna_pse dp, 
  dna_resource_item dri
where
  dpse.pse_id = pb.pse_pse_id
and
  drio.drio_id = dpse.drio_id
and
  dpse.pse_id = dp.pse_id
and
  dri.dri_id = dp.dna_id
and
  pb.bs_barcode = ?/, 'ListOfList'); 
    $self->{'GetAvailableDNAResourceItems'} = LoadSql($dbh,  qq/select 
  count(distinct dri.dri_id) 
from 
  dna_resource_item_order drio, 
  dna_resource_item_order_pse dpse, 
  pse_barcodes pb, 
  dna_pse dp, 
  dna_resource_item dri
where
  dpse.pse_id = pb.pse_pse_id
and
  drio.drio_id = dpse.drio_id
and
  dpse.pse_id = dp.pse_id
and
  dri.dri_id = dp.dna_id
and
  pb.bs_barcode = ?/, 'ListOfList'); 
    $self->{'GetAvailableDNAResourceItemOrder'} = LoadSql($dbh,  qq/select 
  distinct drio.drio_id 
from 
  dna_resource_item_order drio, 
  dna_resource_item_order_pse dpse, 
  pse_barcodes pb, 
  dna_pse dp, 
  dna_resource_item dri
where
  dpse.pse_id = pb.pse_pse_id
and
  drio.drio_id = dpse.drio_id
and
  dpse.pse_id = dp.pse_id
and
  dri.dri_id = dp.dna_id
and
  pb.bs_barcode = ?/, 'ListOfList');
    $self->{'GetContactDNAResourceItemOrder'} = LoadSql($dbh,  qq/select 
  distinct c.contact_email, gu.email
from 
  dna_resource_item_order drio, 
  dna_resource_item_order_pse dpse, 
  process_step_executions pse,
  pse_barcodes pb, 
  dna_pse dp, 
  dna_resource_item dri,
  contact c,
  employee_infos ei,
  gsc_users gu
where
  c.con_id = dri.con_id
and
  dpse.pse_id = pse.pse_id
and
  pse.ei_ei_id = ei.ei_id
and
  gu.gu_id = ei.gu_gu_id
and
  dpse.pse_id = pb.pse_pse_id
and
  drio.drio_id = dpse.drio_id
and
  dpse.pse_id = dp.pse_id
and
  dri.dri_id = dp.dna_id
and
  pb.bs_barcode = ?/, 'ListOfList');
  
    #Need to filter to get only the dna resource item barcodes. 
    $self->{'GetDNAResourceItemBarcode_old'} = LoadSql($dbh,  qq/select 
  distinct pb.bs_barcode, bs.barcode_description
from 
  dna_resource_item_order drio, 
  dna_resource_item_order_pse dpse, 
  pse_barcodes pb,
  barcode_sources bs, 
  dna_pse dp, 
  dna_resource_item dri
where
  pb.bs_barcode = bs.barcode
and
  dpse.pse_id = pb.pse_pse_id
and
  drio.drio_id = dpse.drio_id
and
  dpse.pse_id = dp.pse_id
and
  dri.dri_id = dp.dna_id
and
  dp.pse_id = ? and bs.barcode_description = 'dna resource item'/, 'ListOfList'); 
    $self->{'GetDNAResourceItemBarcode_old'} = LoadSql($dbh,  qq/select 
  distinct pb.bs_barcode, bs.barcode_description
from
  dna_resource_item_order drio, 
  dna_resource_item_order_pse dpse, 
  dna_relationship dr, 
  dna_pse dp, 
  dna d, 
  dna_pse dp1, 
  pse_barcodes pb, 
  barcode_sources bs 
where
  drio.drio_id = dpse.drio_id
and
  dpse.pse_id = dp.pse_id 
and
  dr.parent_dna_id = dp.dna_id 
and
  dr.dna_id = d.dna_id
and
  dp1.dna_id = d.dna_id
and
  dp1.pse_id = pb.pse_pse_id
and
  pb.bs_barcode = bs.barcode
and
  dp.pse_id = ? and bs.barcode_description = 'dna resource item'/, 'ListOfList'); 


$self->{'GetDNAResourceItemBarcode'} = LoadSql($dbh,  qq/select 
  distinct pb.bs_barcode, drc.dna_resource_prefix, dri.dna_resource_item_name
from
  dna_resource_item_order drio, 
  dna_resource_item_order_pse dpse, 
  dna_resource_item dri, 
  dna_resource drc,
  dna_relationship dr, 
  dna_relationship dr1, 
  dna_relationship dri_dr,
  dna_pse dp, 
  dna d, 
  dna_pse dp1, 
  pse_barcodes pb, 
  barcode_sources bs 
where
  drio.drio_id = dpse.drio_id
and
  dpse.pse_id = dp.pse_id 
and
  dr.parent_dna_id = dp.dna_id 
and
  dri_dr.dna_id = dri.dri_id
and
  drc.dr_id = dri_dr.parent_dna_id
and
  dr.dna_id = d.dna_id
and
  dr1.dna_id = d.dna_id
and
  dr1.parent_dna_id = dri.dri_id
and
  dp1.dna_id = d.dna_id
and
  dp1.pse_id = pb.pse_pse_id
and
  pb.bs_barcode = bs.barcode
and
  dp.pse_id = ? and bs.barcode_description = 'dna resource item'/, 'ListOfList');


    $self->{'GetDNAResourceItemDNA'} = LoadSql($dbh,  qq/select 
  distinct dp1.dna_id, dp1.pse_id, dp1.dl_id 
from 
  dna_resource_item_order drio, 
  dna_resource_item_order_pse dpse, 
  pse_barcodes pb, 
  dna_pse dp, 
  dna_pse dp1, 
  dna_resource_item dri,
  process_step_executions pse,
  dna_relationship dr
where
  dp1.pse_id = pse.pse_id
and
  dr.dna_id = dp1.dna_id 
and
  dp.dna_id = dr.parent_dna_id
and
  dpse.pse_id = pb.pse_pse_id
and
  drio.drio_id = dpse.drio_id
and
  dpse.pse_id = dp.pse_id
and
  dri.dri_id = dp.dna_id
and
  dp.pse_id = ?
and
  pse.psesta_pse_status = ?/, 'ListOfList'); 
  


$self->{'GetPDO'} = LoadSql($dbh,  qq/select 
  pdo.pse_pse_id, pdo.data_value, pso.pso_id, pso.output_description, pso.ps_ps_id
from 
  pse_data_outputs pdo, 
  process_step_outputs pso 
where 
  pso.pso_id = pdo.pso_pso_id 
and 
  pdo.pse_pse_id in (
select distinct dp.pse_id from dna d, dna_pse dp where dp.dna_id = d.dna_id and d.dna_id in (
select distinct dna_id from dna_relationship dr start with dna_id in (
select distinct dna_id from dna_pse dp, pse_barcodes pb where
dp.pse_id = pb.pse_pse_id and
 pb.bs_barcode = ?
 ) connect by dna_id = prior dr.parent_dna_id))/, 'ListOfList');  
  
  $self->{'GetAvailableDNAPSE'} = LoadSql($dbh,  qq/select * 
  from dna d, dna_relationship dr where d.dna_id = dr.dna_id and parent_dna_id = ?/, 'ListOfList');
  
  $self->{'GetPhageTestForThisBarcode'} = LoadSql($dbh,  qq/select distinct pse.* 
	from 
	pse_barcodes barx, 
	process_step_executions pse
	where 
	barx.pse_pse_id = pse.pse_id and
	pse.psesta_pse_status in ( 'inprogress', 'completed' ) and 
	barx.bs_barcode = ? and barx.direction = ? and pse.ps_ps_id in 
	(select ps_id from process_steps where pro_process_to = 'phage test') order by pse.pse_id/, 'ListOfList');	   
    return $self;
}


################################################################################
#                                                                              #
#                               Input verification subroutines                 #
#                                                                              #
################################################################################
=head1 GetAvailResourceItemOrderOutInprogress

Get the available resource item order out inprogress.

=cut

sub GetAvailResourceItemOrderOutInprogress {
    my $self = shift;
    my $r = $self->GetAvailBarcodeOutInprogress(@_);
    if(defined $r) {
      my $c = $self->GetAvailableDNAResourceItems(@_);
      if(defined $c) {
        $r->[1] = "DNA Resource Item Order with " . $c->[0] . " order item(s)";
      }
    }
    return ($r->[1], [$r->[0]]);
}

=head1 GetAvailResourceItemOutScheduled

Get the available resource item out scheduled.
1. For the dna resource item
    i) check for the create dna in "scheduled"
   ii) check for the accept dna resource item order in "inprogress" or "completed"
2. If the 2(i) true and 2(ii) true, return true; otherwise false.

=cut

sub GetAvailResourceItemOutScheduled {
    my $self = shift;
    my($barcode, $ps_id, $isNoAcceptCheck) = (@_);
    my $r = $self->GetAvailBarcodeOutScheduled(@_);
    if(defined $r) {
      my @psebarcodes = GSC::PSEBarcode->get(barcode => $barcode, direction => "out");
      if(! @psebarcodes) {
	  $self->{'Error'} = "$pkg: GetAvailResourceItemOutScheduled -> Barcode $barcode does not exist.";
	  return 0;
      }
      if(! $isNoAcceptCheck) {
	my $pse_id = $psebarcodes[0]->pse_id;
	my $lol = $self->{'IsAcceptDNAResourceItemOrderInThisStatus'}->xSql("inprogress", $pse_id);
	if(! $lol->[0][0]) {
          $lol = $self->{'IsAcceptDNAResourceItemOrderInThisStatus'}->xSql("completed", $pse_id);
	  if(! $lol->[0][0]) {
	    $self->{'Error'} = "$pkg: GetAvailResourceItemOutScheduled -> Accept dna resource item order does not exist for $barcode.";
	    return 0;

	  }
	}
      }
      my $c = $self->GetAvailableDNAResourceItem(@_);
      if(defined $c) {
        $r->[1] = "DNA Resource Item [" . $c->[0] . "]";
      }
    }
    return ($r->[1], [$r->[0]]);
}

=head1 GetAvailResourceItemsOutScheduledWithNoAccept

Get the available resource items out scheduled with no accept check.

Process
-------
1. Get all the dna resource items for the order
2. Foreach of the dna resource items
    i) check for the create dna in "scheduled" 
   ii) check for the accept dna resource item order in "inprogress" or "completed" (This does NOT apply here)
3. If the any 2(i) true and 2(ii) true, return true; otherwise false.

=cut
   
sub GetAvailResourceItemsOutScheduledWithNoAccept {
    my $self = shift;
    my($barcode, $ps_id) = (@_);
    return $self->GetAvailResourceItemsOutScheduled($barcode, $ps_id, 1);
}

=head1 GetAvailDNAResourceItemOrderForPhageTest

Get available DNA Resource Item Order for Phage Test.

=cut

sub GetAvailDNAResourceItemOrderForPhageTest {
    my $self = shift;
    my ($barcode, $ps_id, $isNoAcceptCheck) = @_;
    my $c = $self->GetAvailableDNAResourceItemsWithOrderBarcode(@_);
    my @pses;
    my $desc;
    if($c->[0]) {
      my $countStillScheduled = 0;
      my $count;
      my %uniq;
      foreach my $tbarcode (@$c) {
        if(defined $uniq{$tbarcode}) {
	  next;
	}
        #my @r = $self->GetAvailBarcodeOutScheduled($tbarcode, $ps_id);
        my @r = $self->GetAvailResourceItemOutInprogress($tbarcode, $ps_id, $isNoAcceptCheck);
	if($r[0]) {
          #Check to see it is already have the phage test.
	  my $p = $self->{'GetPhageTestForThisBarcode'}->xSql($tbarcode, 'in');
	  if(! @$p) {
	    $countStillScheduled ++;
	    push @pses, @{$r[1]};
	  }
	}
	$count ++;
	$uniq{$tbarcode} = 1;
      }
      if($countStillScheduled > 0) {
        $desc = "DNA Resource Item Order with " . $countStillScheduled . "/" . "$count order item(s) are available for process";
      } else {
        $self->{'Error'} = "$pkg: GetAvailDNAResourceItemOrderForPhageTest -> No DNA Resource Item in schedule for the $barcode.";
        return 0;
      }
    }
    return ($desc, \@pses);
}

=head1 GetAvailDNAResourceItemForPhageTest

Get available DNA Resource Item for Phage Test.

=cut

sub GetAvailDNAResourceItemForPhageTest {
    my $self = shift;
    my($barcode, $ps_id, $isNoAcceptCheck) = (@_);
    my $r = $self->GetAvailBarcodeOutInprogress(@_);
    if(defined $r) {
      my @psebarcodes = GSC::PSEBarcode->get(barcode => $barcode, direction => "out");
      if(! @psebarcodes) {
	  $self->{'Error'} = "$pkg: GetAvailDNAResourceItemForPhageTest -> Barcode $barcode does not exist.";
	  return 0;
      }
      if(! $isNoAcceptCheck) {
	my $pse_id = $psebarcodes[0]->pse_id;
	my $lol = $self->{'IsAcceptDNAResourceItemOrderInThisStatus'}->xSql("inprogress", $pse_id);
	if(! $lol->[0][0]) {
          $lol = $self->{'IsAcceptDNAResourceItemOrderInThisStatus'}->xSql("completed", $pse_id);
	  if(! $lol->[0][0]) {
	    $self->{'Error'} = "$pkg: GetAvailDNAResourceItemForPhageTest -> Accept dna resource item order does not exist for $barcode.";
	    return 0;

	  }
	}
      }
      my $c = $self->GetAvailableDNAResourceItem(@_);
      if(defined $c) {
        $r->[1] = "DNA Resource Item [" . $c->[0] . "]";
      }
    }
    #Check to see it is already have the phage test.
    my $p = $self->{'GetPhageTestForThisBarcode'}->xSql($barcode, 'in');
    if(! @$p) {
      return ($r->[1], [$r->[0]]);
    } else {    
      $self->{'Error'} = "$pkg: GetAvailDNAResourceItemForPhageTest -> Phage Test has been done for $barcode.";
      return 0;
    }
}

=head1 GetAvailResourceItemsOutScheduled

Get the available resource items out scheduled.

Process
-------
1. Get all the dna resource items for the order
2. Foreach of the dna resource items
    i) check for the create dna in "scheduled"
   ii) check for the accept dna resource item order in "inprogress" or "completed"
3. If the any 2(i) true and 2(ii) true, return true; otherwise false.

=cut

sub GetAvailResourceItemsOutScheduled {
    my $self = shift;
    my ($barcode, $ps_id, $isNoAcceptCheck) = @_;
    my $c = $self->GetAvailableDNAResourceItemsWithOrderBarcode(@_);
    my @pses;
    my $desc;
    if($c->[0]) {
      my $countStillScheduled = 0;
      my $count;
      my %uniq;
      foreach my $tbarcode (@$c) {
        if(defined $uniq{$tbarcode}) {
	  next;
	}
        #my @r = $self->GetAvailBarcodeOutScheduled($tbarcode, $ps_id);
        my @r = $self->GetAvailResourceItemOutScheduled($tbarcode, $ps_id, $isNoAcceptCheck);
	if($r[0]) {
	  $countStillScheduled ++;
	  push @pses, @{$r[1]};
	}
	$count ++;
	$uniq{$tbarcode} = 1;
      }
      if($countStillScheduled > 0) {
        $desc = "DNA Resource Item Order with " . $countStillScheduled . "/" . "$count order item(s) are available for process";
      } else {
        $self->{'Error'} = "$pkg: GetAvailResourceItemsOutScheduled -> No DNA Resource Item in schedule for the $barcode.";
        return 0;
      }
    }
    return ($desc, \@pses);
}
=head1 GetAvailResourceItemsInInprogress

Get the available resource items out scheduled.

Process
-------
1. Get all the dna resource items for the order
2. Foreach of the dna resource items
    i) check for the create dna in "scheduled"
   ii) check for the accept dna resource item order in "inprogress" or "completed"
3. If the any 2(i) true and 2(ii) true, return true; otherwise false.
   
   

=cut

sub GetAvailResourceItemsInInprogress {
    my $self = shift;
    my ($barcode, $ps_id) = @_;
    my $c = $self->GetAvailableDNAResourceItemsWithOrderBarcode(@_);
    my @pses;
    my $desc;
    if($c->[0]) {
      my $countStillScheduled = 0;
      my $count;
      my %uniq;
      foreach my $tbarcode (@$c) {
        if(defined $uniq{$tbarcode}) {
	  next;
	}
        my @r = $self->GetAvailBarcodeInInprogress($tbarcode, $ps_id);
	if($r[0]) {
	  $countStillScheduled ++;
	  push @pses, @{$r[1]};
	}
	$count ++;
	$uniq{$tbarcode} = 1;
      }
      if($countStillScheduled > 0) {
        $desc = "DNA Resource Item Order with " . $countStillScheduled . "/" . "$count order item(s) are available for process";
      } else {
        $self->{'Error'} = "$pkg: GetAvailResourceItemsOutScheduled -> No DNA Resource Item in schedule for the $barcode.";
        return 0;
      }
    }
    return ($desc, \@pses);
}
=head1 GetAvailableDNAResourceItemsWithOrderBarcode
=cut
sub GetAvailableDNAResourceItemsWithOrderBarcode {
    my $self = shift;
    my($barcode, $ps_id) = @_;
    my $lol = $self->{'GetAvailableDNAResourceItemsWithOrderBarcode'}->xSql($barcode);
   
    return [map { $_->[0] } @$lol] if(defined $lol->[0][0]);

    $self->{'Error'} = "$pkg: GetAvailableDNAResourceItemsWithOrderBarcode() -> Could not find available resource item for the resource item order barcode $barcode.";
    return 0;

}

=head1 GetAvailResourceItemOrderOutInprogressOrCompleted

Get the available resource item order out inprogress or completed.

=cut

sub GetAvailResourceItemOrderOutInprogressOrCompleted {
    my $self = shift;
    my $r = $self->GetAvailBarcodeOutInprogressOrCompleted(@_);
    if(defined $r) {
      my $c = $self->GetAvailableDNAResourceItems(@_);
      if(defined $c) {
        $r->[1] = "DNA Resource Item Order with " . $c->[0] . " order item(s)";
      }
    }
    return ($r->[1], [$r->[0]]);
}



################################################################################
#                                                                              #
#                              Output verification subroutines                 #
#                                                                              #
################################################################################

=head1 CheckIfCorrectDNAResourceItemOutput

Check if the correct DNA Resource Item output

=cut

sub CheckIfCorrectDNAResourceItemOutput {
    my ($self, $barcode) = @_;

}
=head1 GetAvailableDNAResourceItems

 Get the Available DNA Resource Order Item for the Order  

=cut

sub GetAvailableDNAResourceItems {

    my ($self, $barcode) = @_;

    my $lol = $self->{'GetAvailableDNAResourceItems'}->xSql($barcode);
   
    return [map { $_->[0] } @$lol] if(defined $lol->[0][0]);

    $self->{'Error'} = "$pkg: GetAvailableDNAResourceItems() -> Could not find available resource item for the resource item order barcode $barcode.";
    return 0;

} #GetAvailableDNAResourceItem

=head1 GetAvailableDNAResourceItem

 Get the Available DNA Resource Order Item for the Order  

=cut

sub GetAvailableDNAResourceItem {

    my ($self, $barcode) = @_;

    my $lol = $self->{'GetAvailableDNAResourceItem'}->xSql($barcode);
   
    return [map { $_->[1] } @$lol] if(defined $lol->[0][1]);

    $self->{'Error'} = "$pkg: GetAvailableDNAResourceItem() -> Could not find available resource item for the resource item order barcode $barcode.";
    return 0;

} #GetAvailableDNAResourceItems

################################################################################
#                                                                              #
#                         Confirm Subrotine Processes                          #
#                                                                              #
################################################################################
=head1 AcceptDNAResourceItemOrder

Accept DNA Resource Item Order

Process:

1. Create new pse id for this step
   a. Set the DNA Resource to completed
   b. Set the DNA Resource Item from scheduled to inprogress
2. Send e-mail to the people defined
3. Print Resource Item barcodes

=cut

sub AcceptDNAResourceItemOrder {
    my($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
    #Completed the DNAResourceItemOrder PSEs
    my %dri_barcodes;
    #LSF[20040203]: It only give me the pre_pse_id for the create dna resource item order
    #               I need to find all the dna resource item (create dna container step).
    #               For each of it will be pre_pse_id to create the accept dna resource item order.
    #               1. Completed the create dna resource item order step.
    #               2. For each of the dna resource item create a new pse and link the 
    #                  dna resource item order and dna resource items barcode to the pse.
    #                  
    foreach my $pre_pse_id (@{$pre_pse_ids}) {
	my $result = $self->Process('UpdatePse', 'completed', 'successful', $pre_pse_id);
	
	return 0 if($result == 0);
	#Find all the pre_pse_ids for the dna resource item.
	
	
	#Find all the DNA Resource Item
	#my @dripse = GSC::PSE->get(prior_pse_id => $pre_pse_id);
	#foreach my $ttpse (@dripse) {

	# this returns ($barcode, $prefix, $item_name)
	  my $lol = $self->{'GetDNAResourceItemBarcode'}->xSql($pre_pse_id);
	  #my $lol = $self->{'GetDNAResourceItemBarcode'}->xSql($ttpse->pse_id);
	  foreach my $barcode (@$lol) {
	    $dri_barcodes{$barcode->[0]} = {
	      label => $barcode->[2],
	      number => 1,
	    };
	  }
	#}
    }
   
    #Setup new pse for the order
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $pre_pse_id = $pre_pse_ids->[0];
    my ($new_pse_id) = $self->xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], $bars_out, $emp_id);
    
    #$update_status = 'inprogress';
    #$update_result = '';
    
    my $lol = $self->{'GetAvailableDNAResourceItemOrder'}->xSql($bars_in->[0]);
    if($lol->[0][0]) {
      my $drio_id = $lol->[0][0];
      my $driop = GSC::DNAResourceItemOrderPSE->create(drio_id => $drio_id, pse_id => $new_pse_id);
      #Send e-mail to the people defined if failure only
      #print "=> DIR BARCODE [", Dumper(%dri_barcodes), "]${$options->{printer}}";
      #Print Resource Item barcodes
      if((keys %dri_barcodes) > 0) {
        if($self->PrintBarcodes(\%dri_barcodes, 1, ${$options->{printer}})) {
	  return 0;
	}
      }
      #Link the pse barcode.
      #foreach my $barcode (keys %dri_barcodes) {
      #	my $pse_barcode = GSC::PSEBarcode->create(pse_id => $new_pse_id,
      #                                  	 barcode => $barcode,
      #						 direction => 'in');
      #}
      my $pdos = $self->getPDO(barcode => $bars_in->[0]);
      my $isQCTest;
      my $isPhageTest;
      foreach my $pdo (@$pdos) {
	if($pdo->{output_description} eq "phage test") {
          $isPhageTest = $pdo->{data_value};
	} elsif($pdo->{output_description} eq "qc test") {
          $isQCTest = $pdo->{data_value};
	}
      }

      if(! $isPhageTest) {
	#Set the create dna container to 'inprogress'
        my $lol = $self->{'GetAvailableDNAResourceItemsWithOrderBarcode'}->xSql($bars_in->[0]);
	foreach my $l (@$lol) {
          #push @pbarcodes, $l->[0];
	  #$info{$l->[0]} = $l;
	  my($tb, $td, $tpse_id, $tpstatus, $tpdrin) = @$l;
	  if($tpstatus eq "scheduled") {
	    my $result =  $self->Process('UpdatePse', "inprogress", "", $tpse_id);
	    return 0 if(!$result);    
	  }
        }	
      }
      return [$new_pse_id];
    }
    $self -> {'Error'} = "$pkg: AcceptDNAResourceItemOrder() -> The DNA Resource Item Order of this barcode $bars_in->[0] can not be read ";
    return 0;
}

=head1 FailDNAResourceItemOrder

Fail the DNA Resource Item order

LSF[20040205]: Check the logic for this.

=cut

sub FailDNAResourceItemOrder_old {
    my($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
    print Dumper(ref($self));
    #Completed the DNAResourceItemOrder PSEs
    my %dri_barcodes;
    foreach my $pre_pse_id (@{$pre_pse_ids}) {
      my $result = $self->Process('UpdatePse', 'completed', 'unsuccessful', $pre_pse_id);
      return 0 if($result == 0);
      #Find all the DNA Resource Item
      my $lol = $self->{'GetDNAResourceItemDNA'}->xSql($pre_pse_id, 'inprogress');
      foreach my $l (@$lol) {
 	my $uresult = $self->Process('UpdatePse', 'completed', 'unsuccessful', $l->[1]);      
        return 0 if($uresult == 0);
      }
    }
    #Setup new pse for the order
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $pre_pse_id = $pre_pse_ids->[0];
    my ($new_pse_id) = $self->xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], $bars_out, $emp_id);
    my $lol = $self->{'GetAvailableDNAResourceItemOrder'}->xSql($bars_in->[0]);
    if($lol->[0][0]) {
      my $drio_id = $lol->[0][0];
      my $driop = GSC::DNAResourceItemOrderPSE->create(drio_id => $drio_id, pse_id => $new_pse_id);
      #Send e-mail to the people defined
      my @users;
      #Get the person created the item order 
      #Get the person e-mail from dna_resource con_id
      my $clol = $self->{'GetContactDNAResourceItemOrder'}->xSql($bars_in->[0]);
      foreach my $c (@$clol) {
        push @users, @$c;
      }
      #Email it out.
      my $message =<<EOT;
Dear User,

   The dna resource item order for the barcode $bars_in->[0] is having problem.
Please check it out.

   Thank you.
   
   Automatic Notification System
      
EOT
      #print Dumper(@users);
      $self->Mail(\@users, "Fail DNA Resource Item Order for the $bars_in->[0]", $message);
      #Print Resource Item barcodes
      return [$new_pse_id];
    }
    $self -> {'Error'} = "$pkg: FailDNAResourceItemOrder() -> The DNA Resource Item Order of this barcode $bars_in->[0] can not be read ";
    return 0;
}
sub FailDNAResourceItemOrder {
    my($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
    my $data_options = $options->{'Data'};
    my %pre_pse_bar;

    foreach my $pre_pse_id (@$pre_pse_ids) {
      $pre_pse_bar{$pre_pse_id} = "";
    }
    
    #Setup new pse for the order
    #LSF: Cannot completed the prior step since the prior step is the create dna container.
    #It is inprogress or scheduled depend on it need the qc test or not.
    #Find this from create dna resource item order step.
    my @pse_ids;
    #LSF: How to find out this?
    
    my $update_status = 'completed';
    my $update_result = 'unsuccessful';
    
    #Transfer the DNAResourceItem or DNAResourceItemOrder
    my $lol = $self->{'GetAvailableDNAResourceItemsWithOrderBarcode'}->xSql($bars_in->[0]);
    my %info;
    my @pbarcodes;
    my %bar_pre_pse;
    my $gbarcode = $bars_in->[0];
    if($lol->[0][0]) {
      foreach my $l (@$lol) {
        #LSF: Since the prior pse ids will be passed in here.
	#     we will use this to make sure we do not process
	#     those items that we cannot process.
	#push @pbarcodes, $l->[0];
	#$info{$l->[0]} = $l;
	my($tb, $td, $tpse_id, $tpstatus, $tpdrin) = @$l;
	if(defined $pre_pse_bar{$tpse_id}) {
	  push @pbarcodes, $l->[0];
	  $info{$l->[0]} = $l;
	  $pre_pse_bar{$tpse_id} = $tb;
	  $bar_pre_pse{$tb} = $tpse_id;
	}
      }
    } else {
      my @psebars = GSC::PSEBarcode->get(sql => [qq/select pb.* from dna_relationship dr, pse_barcodes pb, dna_pse dp, dna_pse dp1
 where
      dp1.pse_id = pb.pse_pse_id
    and
      pb.direction = 'out'
    and
      dr.parent_dna_id = dp1.dna_id
     and
      dr.dna_id = dp.dna_id 
    and
      dp.pse_id in (select distinct pb.pse_pse_id from pse_barcodes pb where pb.bs_barcode = ? and direction = 'out')/, $bars_in->[0]]);
      foreach my $psebar (@psebars) {
        $gbarcode = $psebar->barcode;
      }
      push @pbarcodes, $bars_in->[0];
      if(defined $pre_pse_bar{$pre_pse_ids->[0]}) {
	$pre_pse_bar{$pre_pse_ids->[0]} = $bars_in->[0];
	$bar_pre_pse{$bars_in->[0]} = $pre_pse_ids->[0];
      }
    }
    
    foreach my $barcode (@pbarcodes) {
      my ($pse_id) = $self->xOneToManyProcess($ps_id, $bar_pre_pse{$barcode}, $update_status, $update_result, $barcode, $bars_out, $emp_id);
      if($bar_pre_pse{$barcode}) {
	my @dnapses = GSC::DNAPSE->get(pse_id => $bar_pre_pse{$barcode});
	foreach my $tdp (@dnapses) {
	  if(! GSC::DNAPSE->create(dna_id => $tdp->dna_id, pse_id => $pse_id, dl_id => $tdp->dl_id)) {
            $self->{'Error'} = "$pkg: FailDNAResourceItemOrder -> cannot create DNA_PSE for dna_id => dna_id => $tdp->dna_id, pse_id => $pse_id, dl_id => $tdp->dl_id.";
            return 0;
	  }
	}
      } else {
        $self->{'Error'} = "$pkg: FailDNAResourceItemOrder -> Could not find dna pse information for the barcode $bars_in->[0] -> $barcode.";
        return 0;
      }
      push @pse_ids, $pse_id;
    }
    
    my @users;
    #Get the person created the item order 
    #Get the person e-mail from dna_resource con_id
    my $clol = $self->{'GetContactDNAResourceItemOrder'}->xSql($gbarcode);
    foreach my $c (@$clol) {
      push @users, @$c;
    }
    #Email it out.
    my $message =<<EOT;
Dear User,

 The dna resource item order for the barcode $bars_in->[0] is having problem.
Please check it out.

 Thank you.

 Automatic Notification System

EOT
    #print Dumper(@users);
    $self->Mail(\@users, "Fail DNA Resource Item Order for the $bars_in->[0]", $message);
    
    return \@pse_ids;
}

=head1 PhageTest

Phage test. It can either be "block" (An entire order) or "item" (An item) 

1. By Batch - will pass/fail the whole order
2. By Item  - will pass/fail the item only

=cut

sub PhageTest {
    my($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids, $method) = @_;
    $method = $method ? $method : "PhageTest";
    my $data_options = $options->{'Data'};
    my %pre_pse_bar;

    foreach my $pre_pse_id (@$pre_pse_ids) {
      $pre_pse_bar{$pre_pse_id} = "";
    }
    
    #Setup new pse for the order
    #LSF: Cannot completed the prior step since the prior step is the create dna container.
    #It is inprogress or scheduled depend on it need the qc test or not.
    #Find this from create dna resource item order step.
    my @pse_ids;
    #LSF: How to find out this?
    
    my $isQCTest;
    #LSF: How to find out this?
    my $isPhageTest;
    my $pdos = $self->getPDO(barcode => $bars_in->[0]);
    foreach my $pdo (@$pdos) {
      if($pdo->{output_description} eq "phage test") {
        $isPhageTest = $pdo->{data_value};
      } elsif($pdo->{output_description} eq "qc test") {
        $isQCTest = $pdo->{data_value};
      }
    }

    my $update_status = 'inprogress';
    my $update_result = '';
    if($method eq "PhageTest") {
      $update_status = $isQCTest ? 'scheduled' : 'inprogress';
      $update_result = '';
    } else {
      $update_status = 'completed';
      $update_result = 'successful';
    }
    
    #Transfer the DNAResourceItem or DNAResourceItemOrder
    my $lol = $self->{'GetAvailableDNAResourceItemsWithOrderBarcode'}->xSql($bars_in->[0]);
    my %info;
    my @pbarcodes;
    my %bar_pre_pse;
    if($lol->[0][0]) {
      foreach my $l (@$lol) {
        #LSF: Since the prior pse ids will be passed in here.
	#     we will use this to make sure we do not process
	#     those items that we cannot process.
	#push @pbarcodes, $l->[0];
	#$info{$l->[0]} = $l;
	my($tb, $td, $tpse_id, $tpstatus, $tpdrin) = @$l;
	if(defined $pre_pse_bar{$tpse_id}) {
          push @pbarcodes, $l->[0];
	  $info{$l->[0]} = $l;
	  $pre_pse_bar{$tpse_id} = $tb;
	  $bar_pre_pse{$tb} = $tpse_id;
	}
      }
    } else {
      push @pbarcodes, $bars_in->[0];
      if(defined $pre_pse_bar{$pre_pse_ids->[0]}) {
	$pre_pse_bar{$pre_pse_ids->[0]} = $bars_in->[0];
	$bar_pre_pse{$bars_in->[0]} = $pre_pse_ids->[0];
      }
    }
    
    foreach my $barcode (@pbarcodes) {
      my ($pse_id) = $self->xOneToManyProcess($ps_id, $bar_pre_pse{$barcode}, $update_status, $update_result, $barcode, $bars_out, $emp_id);
      if($bar_pre_pse{$barcode}) {
	my @dnapses = GSC::DNAPSE->get(pse_id => $bar_pre_pse{$barcode});
	foreach my $tdp (@dnapses) {
	  if(! GSC::DNAPSE->create(dna_id => $tdp->dna_id, pse_id => $pse_id, dl_id => $tdp->dl_id)) {
            $self->{'Error'} = "$pkg: $method() -> cannot create DNA_PSE for dna_id => dna_id => $tdp->dna_id, pse_id => $pse_id, dl_id => $tdp->dl_id.";
            return 0;
	  }
	}
      } else {
        $self->{'Error'} = "$pkg: $method() -> Could not find dna pse information for the barcode $bars_in->[0] -> $barcode.";
        return 0;
      }
      #If there isn't qctest, completed the step.
      if(! $isQCTest) {
        #Complete the step $pse_id
	my $update_status = 'completed';
	my $update_result = 'successful';
	my $result =  $self->Process('UpdatePse', $update_status, $update_result, $pse_id);
	return 0 if(!$result);
      }
      
      if($method ne "PhageTest") {
        #Set the status to 'inprogress' for the create dna container step.
      }
      push @pse_ids, $pse_id;
    }
=head1 comment
    #
    foreach my $pso_id (keys %{$data_options}) {
      my $info = $data_options->{$pso_id};
      if(defined $info) {
	my $sql = GSC::ProcessStepOutput->get(pso_id => $pso_id);
	my $desc = Query($self->{'dbh'}, $sql);
	if($desc eq 'status') {
          if(! GSC::PSEDataOutput->create(pse_id => $pse_id, pso_id => $pso_id, data_valuie => $$info)) {	        
            $self->{'Error'} = "$pkg: PhageTest() -> Could not create PSEDataOutput for values pse_id => $pse_id, pso_id => $pso_id, data_valuie => $$info.";
	    return 0;
	  }
	}
      }
    }
    #Check for the $bars_in type
    #my $ps = GSC::ProcessStep->get(ps_id => $ps_id);
    #foreach my $barcode (@$bars_in) {
    #  if($ps->barcode_prefix_input)
    #}
    #GSC::DNARelationship->get(parent_dna_id => $dna_id);
    my $TouchSql = TouchScreen::TouchSql->new($self->{'dbh'}, $self->{'Schema'});

    my ($pso_id, $data, $lov) = $TouchSql->GetPsoInfo($ps_id, 'status');
    if(!$pso_id) {
	$self->{'Error'} = $TouchScreen::TouchSql::Error;
	return 0;
    }

    if(! $TouchSql -> InsertPsePsoInfo($pse_id, $pso_id, ${$data_options->{$pso_id}})) {
      $self->{'Error'} = "$pkg: PhageTest() -> Could not create PSEDataOutput for values pse_id => $pse_id, pso_id => $pso_id, data_valuie => $$info.";
      return 0;
    }
=cut
    return \@pse_ids;
}

=head1 QCTest

QC test

1. By Batch - will pass/fail the whole order
2. By Item  - will pass/fail the item only

=cut

sub QCTest {
    my($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
    shift;
    return $self->PhageTest(@_, "QCTest");
}

=head2 getPDO

=cut
sub getPDO {
  my $self = shift;
  my %param = (@_);
  my $barcode = $param{barcode};
  my $lol = $self->{'GetPDO'}->xSql($barcode);
  my @result;
  foreach my $l (@$lol) {
    my($pse_id, $data_value, $pso_id, $output_description, $ps_ps_id) = @$l;
    push @result, {
      pse_id => $pse_id,
      data_value => $data_value,
      pso_id => $pso_id,
      output_description => $output_description,
      ps_id => $ps_ps_id,
    };
  }
  return \@result;
}

1;
__END__

# $Header$
