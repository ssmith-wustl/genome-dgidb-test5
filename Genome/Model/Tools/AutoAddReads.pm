package Genome::Model::Tools::AutoAddReads;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::AutoAddReads { is => 'Command', };

sub sub_command_sort_position { 23 }

sub help_brief {
"Tool to add reads and build solexa reference-alignment genome models that are configured for automatic processing"
      ,;
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt auto-add-reads ...
EOS
}

sub help_detail {
    return <<EOS
EOS
}

sub execute {
    my $self = shift;

    foreach my $mod ( Genome::Model::ReferenceAlignment->get() ) {
        my $cmd =
            'genome model instrument-data assign --model-id='
          . $mod->genome_model_id()
          . ' --all';
    }

    foreach my $assign_model (
        Genome::Model::ReferenceAlignment->get( auto_assign_inst_data => 1 ) )
    {
        Genome::Model::Command::InstrumentData::Assign->execute(model_id => $assign_model->genome_model_id(),all=>1);
     }

   
    return 1;
}

1;
