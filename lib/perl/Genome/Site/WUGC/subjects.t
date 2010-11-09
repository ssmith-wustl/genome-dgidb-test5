#!/usr/bin/env perl

use strict;
use warnings;
use above "Genome";
use Test::More;

my @classes = qw/
    GSC::DNAResource           
    GSC::DNAResourceItem       
    GSC::IPRProduct            
    GSC::SolexaRun
    GSC::GenomicDNA            
    GSC::Ligation              
    GSC::PCRProduct            
/;

plan tests => scalar(@classes) * 3;

for my $class (@classes) {
    my $c2 = $class;
    $c2 =~ s/GSC::/Genome::Site::WUGC::/g;
    my $o = eval {
        my $i = $c2->create_iterator();
        my $o = $i->next;
        return $o;
    };
    ok($o, "got object for $c2");
    ok($o->id, "got id " . $o->id);
    ok($o->name, "got name " . $o->name);
}

__END__
SUBJECT_CLASS_NAME          COUNT(*)
------------------          --------
GSC::DNAResource            2
GSC::DNAResourceItem        459
GSC::IPRProduct             3
GSC::GenomicDNA             46
GSC::Ligation               48
GSC::PCRProduct             101
GSC::Equipment::Solexa::Run 20
Genome::PopulationGroup     9
Genome::ModelGroup          307
Genome::Taxon               530
Genome::Model               888
Genome::Individual          1315
Genome::Library             1763
Genome::Sample              26940
Genome::Sys::Command        4
UR::Value                   4
