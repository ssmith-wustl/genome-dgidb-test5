package Genome::Model::Tools::UploadAmlValidationMasterList;

use strict;
use warnings;
use Data::Dumper;
use IO::File;
use Genome::VariantReviewDetail;
use Genome::VariantReviewListFilter;
use Genome::VariantReviewListMember;
use Genome::VariantReviewList;

use above "Genome";

UR::Object::Type->define(
    class_name => __PACKAGE__, is => 'Command',
    has => [
        list => {
            is => 'String',
            doc => 'Master csv to import', 
        },
    ],
    has_optional => [
        separation_character =>{
            is => 'String',
            doc => 'character or string that separates the fields in the list',
            default => '|',
        },
        author => { 
            is => 'String', 
            doc => 'Author or authors of the list',
        },
        filter => { 
            is => 'String', 
            doc => 'Filter, filters, or description of criteria use to generate the list',
        },
        rt_ticket => { 
            is => 'String', 
            doc => 'RT ticket id number',
        },
    ]
);

sub execute {
    my $self = shift;

    $self->status_message("This module is no longer intended for normal use");
    $DB::single = 1;

=cut
    eval "use GSCApp; App::DB->db_variant('development'); App::DB->db_access_level('rw'); App->init";
    if ($@) {
        $self->error_message("Error initializing GSCApp! $@");
        return;
    }
    
    unless(App::DB->sync_database) {
        $self->error_message("Failed to save GSC objects: " . App::DB->error_message);
        return;
    }
    $self->create_subscription("commit", 
        sub {  
            #App::DB->commit 
            print "committing!\n";
        }
    );
=cut

    my $separation_character = $self->separation_character;
    
    my $fh = IO::File->new("< ".$self->list);
    unless ($fh){
        $self->error_message("Couldn't open list file for reading!");
        return;
    }

    eval{
        while (my $line = $fh->getline){
            chomp $line;
            my $current_line = $line;
            my @data = split(/\Q$separation_character\E/, $line);

            my ($list, $chromosome, $begin_position, $end_position, $variant_type, $variant_length, $delete_sequence, $insert_sequence, $genes, $supporting_samples, $supporting_dbs, $finisher_manual_review, $pass_manual_review, $finisher_3730_review, $manual_genotype_normal, $manual_genotype_tumor, $manual_genotype_relapse, $somatic_status, $notes) = @data;

            foreach ($list, $chromosome, $begin_position, $end_position, $variant_type, $variant_length, $delete_sequence, $insert_sequence, $genes, $supporting_samples, $supporting_dbs, $finisher_manual_review, $pass_manual_review, $finisher_3730_review, $manual_genotype_normal, $manual_genotype_tumor, $manual_genotype_relapse, $somatic_status, $notes){
                if ($_){
                    $_ =~ s/"//g;
                    undef $_  if $_ =~ /^-$/;
                }
            }
            my $name = $list;
            my $filter = $name;
        
            my $review_list = Genome::VariantReviewList->get(name => $name);

            unless ($review_list){
                $review_list = Genome::VariantReviewList->create(name => $name);
                my $review_list_filter = Genome::VariantReviewListFilter->create(filter_name => $filter, list_id => $review_list->id);
            }
            
            my $list_id = $review_list->id;

            my ($insert_sequence_allele1, $insert_sequence_allele2) = split (/\//, $insert_sequence);

            my $current_member = Genome::VariantReviewDetail->get( begin_position => $begin_position, chromosome => $chromosome, end_position => $end_position, variant_type => $variant_type, delete_sequence => $delete_sequence, insert_sequence_allele1 => $insert_sequence_allele1, insert_sequence_allele2 => $insert_sequence_allele2 );
            if ($current_member){
                my $new_notes = $self->vtest($current_member->notes);
                $new_notes .= ', ' if $new_notes and $notes;
                $new_notes .= $notes if $notes;
                $current_member->notes($new_notes);
            }else{
                $current_member = Genome::VariantReviewDetail->create(
                    chromosome              => $chromosome,
                    begin_position          => $begin_position,
                    end_position            => $end_position,
                    variant_type            => $variant_type,
                    variant_length          => $variant_length,
                    delete_sequence         => $delete_sequence, 
                    insert_sequence_allele1 => $insert_sequence_allele1,
                    insert_sequence_allele2 => $insert_sequence_allele2,
                    genes                   => $genes,
                    supporting_samples      => $supporting_samples,
                    supporting_dbs          => $supporting_dbs,
                    finisher_manual_review  => $finisher_manual_review,
                    pass_manual_review      => $pass_manual_review,
                    finisher_3730_review    => $finisher_3730_review,
                    manual_genotype_normal  => $manual_genotype_normal,
                    manual_genotype_tumor   => $manual_genotype_tumor,
                    manual_genotype_relapse => $manual_genotype_relapse,
                    somatic_status          => $somatic_status,
                    notes                   => $notes,

                    rgg_id                  => undef,
                    roi_seq_id              => undef,
                    sample_name             => undef,
                    variant_seq_id          => undef,
                );
            }
            my $member_id = $current_member->id;
            my $review_list_member = Genome::VariantReviewListMember->get_or_create(
                list_id => $list_id,
                member_id => $member_id,
            );

        }  #while ( my $line = getline);
    };
    
    if ($@){
        $self->error_message("error in execution. $@");
        return 0;
    }
    return 1;
}

sub vtest{
    my ($self, $v) = @_;
    return $v? $v : '';
}

1;
