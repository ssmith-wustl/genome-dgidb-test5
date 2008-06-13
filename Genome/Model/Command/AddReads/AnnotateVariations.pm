package Genome::Model::Command::AddReads::AnnotateVariations;

use strict;
use warnings;

use above "Genome";

use Genome::Model::Command::Report::VariationsBatchToLsf;
use Genome::Model::EventWithRefSeq;
use Command;

class Genome::Model::Command::AddReads::AnnotateVariations {
    is => [ 'Genome::Model::EventWithRefSeq' ],
    has => [
            unique_snp_array => {
                                 is => 'list',
                                 doc => "",
                                 is_transient => 1,
                                 is_optional =>1,
                             },
           ],
    sub_classification_method_name => 'class',
};

#########################################################

sub sub_command_sort_position { 90 } # TODO needed?

# TODO Add doc
sub help_brief {
    "Automates variant annotation reporting during add reads"
}

sub help_synopsis {
    return;
}

sub help_detail {
    return <<"EOS"
This module implements the automation of annotating variants discovered during the add reads pipeline.
For the actual annotation process see: 
Genome::SnpAnnotator
For the report process (which runs the annotator) see:
Genome::Model::Command::Report::Variations 
Genome::Model::Command::Report::VariationsBatchToLsf
EOS
}

sub snp_report_file {
    my $self = shift;

    return $self->_report_file('snp');
}

sub indel_report_file {
    my $self = shift;

    return $self->_report_file('indel');
}

sub _report_file {
    my ($self, $type) = @_;

    return sprintf('%s/variant_report_for_chr_%s', ($self->model->_reports_dir)[0], $self->ref_seq_id);
    return sprintf('%s/%s_report_%s', $type, ($self->model->_reports_dir)[0], $self->ref_seq_id);
}

sub execute {
    my $self = shift;
    
    my $chromosome_name = $self->ref_seq_id;
    my $model = $self->model;
    my ($detail_file) = $model->_variant_detail_files($chromosome_name);
    my $log_dir = $self->resolve_log_directory;

    $DB::single = 1; # when debugging, stop here...

    my ($reports_dir) = $model->_reports_dir();
    print "$reports_dir\n";
    unless (-d $reports_dir) {
        mkdir $reports_dir;
        `chmod g+w $reports_dir`;
    }

    my $success = Genome::Model::Command::Report::VariationsBatchToLsf->execute
    (
        chromosome_name => $chromosome_name,
        variation_type => 'snp', # TODO run for each type
        variant_file => $detail_file,
        report_file => sprintf('%s/snp_report_%s', $reports_dir, $chromosome_name),
        #report_file => $self->snp_report_file,
        out_log_file => sprintf('%s/%s.out', $log_dir, $self->lsf_job_id || $chromosome_name),
        error_log_file => sprintf('%s/%s.err', $log_dir, $self->lsf_job_id || $chromosome_name),
        # OTHER PARAMS:
        # flank_range => ??,
        # variant_range => ??,
        # format => ??,
    );

    if ( $success )
    { 
        $self->event_status("Succeeded");
    }
    else 
    {
        $self->event_status("Failed");
    }

    $self->date_completed( UR::Time->now );

    return $success;
}

###Metrics-------------------------------

sub metrics_for_class {
    my $class = shift;

    my @metric_names = qw(
                          SNV_count
                          SNV_in_dbSNP_count
                          SNV_in_venter_count
                          SNV_in_watson_count
                          SNV_distinct_count
                          HQ_SNP_count
                          HQ_SNP_reference_allele_count
                          HQ_SNP_variant_allele_count
                          HQ_SNP_both_allele_count
    );

    return @metric_names;
}

sub SNV_count {
    my $self=shift;
    return $self->get_metric_value('SNV_count');
}

##########THESE METHODS SHOULD PROLLY CLOSE THEIR FILE HANDLES TOO, YO#######
sub _calculate_SNV_count {
    my $self= shift;
    my @snvs = @{$self->return_unique_snp_array()};
    return scalar(@snvs);
}


    


sub SNV_in_dbSNP_count {
    my $self=shift;
    return $self->get_metric_value('SNV_in_dbSNP_count');
}

sub _calculate_SNV_in_dbSNP_count {
    my $self= shift;
    my @snvs = @{$self->return_unique_snp_array()};
    my $c=0; 
    for my $snv (@snvs) {
        $c++ if $snv->[0] == 1;
    }
    return $c;
}

sub SNV_in_watson_count {
    my $self=shift;
    return $self->get_metric_value('SNV_in_watson_count');
}

sub _calculate_SNV_in_watson_count {
    my $self= shift;
    my @snvs = @{$self->return_unique_snp_array()};
    my $c=0; 
    for my $snv (@snvs) {
        $c++ if $snv->[21]=~ /watson/i;
    }
    return $c;
}

sub SNV_in_venter_count {
    my $self=shift;
    return $self->get_metric_value('SNV_in_venter_count');
}

sub _calculate_SNV_in_venter_count {
    my $self= shift;
    my @snvs = @{$self->return_unique_snp_array()};
    my $c=0; 
    for my $snv (@snvs) {
        $c++ if $snv->[21]=~ /venter/i;
    }
    return $c;
}

sub SNV_distinct_count {
    my $self=shift;
    return $self->get_metric_value('SNV_distinct_count');
}

sub _calculate_SNV_distinct_count {
    my $self= shift;
    my @snvs = @{$self->return_unique_snp_array()};
    my $c=0; 
    for my $snv (@snvs) {
        $c++ if ($snv->[21] !~ /venter/i && $snv->[21] !~ /watson/i && $snv->[0] == 1);
    }
    return $c;
}

sub HQ_SNP_count {
    my $self=shift;
    return $self->get_metric_value('HQ_SNP_count');
}

sub _calculate_HQ_SNP_count {
    my $self=shift;
    ###how do i do this? I don't know. I should probably word count the filtered snp file, but maybe not.
}

sub HQ_SNP_reference_allele_count {
    my $self=shift;
    return $self->get_metric_value('HQ_SNP_reference_allele_count');
}

sub _calculate_HQ_SNP_reference_allele_count {
    my $self=shift;
    ###how do i do this? I don't know. I should probably word count the filtered snp file then do something else, but maybe not.
}

sub HQ_SNP_variant_allele_count {
    my $self=shift;
    return $self->get_metric_value('HQ_SNP_variant_allele_count');
}

sub _calculate_HQ_SNP_variant_allele_count {
    my $self=shift;
    ###how do i do this? I don't know. I should probably word count the filtered snp file then do something else, but maybe not.
}

sub HQ_SNP_both_allele_count {
    my $self=shift;
    return $self->get_metric_value('HQ_SNP_both_allele_count');
}

sub _calculate_HQ_SNP_both_allele_count {
    my $self=shift;
    ###how do i do this? I don't know. I should probably word count the filtered snp file then do something else, but maybe not.
}

sub return_unique_snp_array {
    my $self=shift;
    if (defined $self->unique_snp_array) {
        return $self->unique_snp_array;
    }
    
    my $snp_file = $self->snp_report_file;
    my $c = 0;
    my $fh = IO::File->new($snp_file);
    my $last_pos=0;
    my $last_base;
    my @unique_list_2_return;
    while (my $line = $fh->getline) {
        my @row = split (/,/, $line);
        if (! @row) {
            print $line;
            last;
        }
        my $pos = $row[3];
        my $linear_distance = $pos - $last_pos; 
        if ($linear_distance > 0) {
            $last_base=$row[5]; 
            push (@unique_list_2_return, \@row);
        }
            elsif ($linear_distance == 0) {
             #there is some lingering uncertainty about this methodology
             ($last_base=$row[5] and push(@unique_list_2_return, \@row)) if($last_base ne $row[5]) ;
        }
        else
        {
            #this block means we got something out of order...PANIC
            $self->error_message("File not sorted...bailing out.");
            return undef;
        } 
        $last_pos=$pos;
    }
    $self->unique_snp_array(\@unique_list_2_return);
    return $self->unique_snp_array;
}

sub cleanup_transient_properties {
    my $self=shift;
    $self->unique_snp_array(undef);
}


1;

#$HeadURL$
#$Id$
