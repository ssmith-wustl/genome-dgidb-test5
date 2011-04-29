package Genome::Site::WUGC::ReconcileSampleGenotypeData;

use strict;
use warnings;
use Genome;

class Genome::Site::WUGC::ReconcileSampleGenotypeData {
    is => 'Genome::Command::Base',
    doc => '',
};

sub execute {
    my $self = shift;

    my @misc_updates = sort{$a->edit_date cmp $b->edit_date} Genome::MiscUpdate->get(
                                                                                    is_reconciled => '0', 
                                                                                    subject_class_name => 'gsc.organism_sample', 
                                                                                    description => 'UPDATE', 
                                                                                    subject_property_name => 'DEFAULT_GENOTYPE_SEQ_ID',
                                                                                    );
    for my $update (@misc_updates){
        my $sample = Genome::Sample->get($update->subject_id);
        print "No Genome::Sample for subject: " , $update->subject_id , "on update: ", $update->id, " , skipping\n" and next unless $sample;
        my $new_value = $update->new_value;
        $sample->set_default_genotype_data($new_value);
        $update->is_reconciled(1);
    }
}

1;
