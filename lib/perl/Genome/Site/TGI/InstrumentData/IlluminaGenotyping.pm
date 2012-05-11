package Genome::Site::TGI::InstrumentData::IlluminaGenotyping; 

use strict;
use warnings;

use Genome;

class Genome::Site::TGI::InstrumentData::IlluminaGenotyping {
    table_name => <<SQL
    (
        select g.seq_id id, g.status status, g.organism_sample_id sample_id,
         s.full_name sample_name
         --dna.dna_id dna_id,
         --spse.pse_id creation_pse_id
        from illumina_genotyping\@dw g
        join organism_sample\@dw s on s.organism_sample_id = g.organism_sample_id
        --left join dna\@oltp dna on dna.dna_name = g.dna_name
        --join sequence_pse\@oltp spse on spse.seq_id = g.seq_id
        where g.status = 'pass'
    ) illumina_genotyping
SQL
    ,
    id_by => [
        id => { is => 'Text', },
    ],
    has => [
        status => { is => 'Text', },
        sample_id => { is => 'Text', },
        sample_name => { is => 'Text', },
        #dna_id => { is => 'Text', is_optional => 1, },
        #creation_pse_id => { is => 'Text', },
        platform_name => { is_constant => 1, calculate => q| return 'Infinium'; |, },
        import_source_name => { is_constant => 1, calculate => q| return 'wugc'; |, },
    ],
    data_source => 'Genome::DataSource::GMSchema',
};

sub Xgenotype_file { # 2878428288
    my $self = shift;
    my $creation_pse = GSC::PSE->get($self->creation_pse_id);
    return if not $creation_pse;
    my $transfer_pse = $creation_pse->get_first_active_subsequent_pse_with_process_to('transfer genome studio analysis');
    return if not $transfer_pse;
    my $path = $transfer_pse->allocate_disk_space_absolute_path;
    return if not $path;
    my $file = "$path/snpreport/".$self->id;
    return $file if -f $file;
    return if not $self->dna_id;
    $file = "$path/snpreport/".$self->dna_id;
    return $file if -f $file;
    return;
}

1;

