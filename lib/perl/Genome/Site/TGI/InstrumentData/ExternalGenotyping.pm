package Genome::Site::TGI::InstrumentData::ExternalGenotyping; 

use strict;
use warnings;

use Genome;

class Genome::Site::TGI::InstrumentData::ExternalGenotyping {
    table_name => <<SQL
    (
        select g.seq_id id, g.status status, g.organism_sample_id sample_id,
         s.full_name sample_name,
	     p.name platform_name
	     --spse.pse_id creation_pse_id
	    from external_genotyping\@dw g
        join genotyping_platform\@dw p on p.genotyping_platform_id = g.genotyping_platform_id
        join organism_sample\@dw s on s.organism_sample_id = g.organism_sample_id
        --join sequence_pse\@oltp spse on spse.seq_id = g.seq_id
    ) external_genotyping
SQL
    ,
    id_by => [
        id => { is => 'Text', },
    ],
    has => [
        status => { is => 'Text', },
        sample_id => { is => 'Text', },
        sample_name => { is => 'Text', },
        #creation_pse_id => { is => 'Text', },
        platform_name => { is => 'Text', },
        import_source_name => { is_constant => 1, calculate => q| return 'external'; |, },
    ],
    data_source => 'Genome::DataSource::GMSchema',
};

sub Xgenotype_file { # 2875456768
    my $self = shift;
    #my $sequence_pse = GSC::Sequence::PSE->get(seq_id => $self->id);
    #return if not $sequence_pse;
    #my $creation_pse = GSC::PSE->get($sequence_pse->pse_id);
    my $creation_pse = GSC::PSE->get($self->creation_pse_id);
    return if not $creation_pse;
    my $import_pse = $creation_pse->get_first_active_subsequent_pse_with_process_to('import external genotype');
    return unless $import_pse;
    my $path = $import_pse->allocate_disk_space_absolute_path;
    return if not $path or not -d $path;
    my $genotype_file = $path . '/' . $self->sample_id . '.genotype';
    return if not -f $genotype_file;
    return $genotype_file;
}

1;

