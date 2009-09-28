package Genome::Model::Tools::AmpliconAssembly::ContaminationScreen;

use strict;
use warnings;

use Genome;    

use Data::Dumper 'Dumper';

class Genome::Model::Tools::AmpliconAssembly::ContaminationScreen {
    is => 'Genome::Model::Tools::AmpliconAssembly',
    has => [
    database => {
        doc => 'Alignment database to screen against', 
        is => 'String',
        is_input => 1,
    },
    ],
    has_optional => [
    remove_contaminants => {
        is => 'Boolean',
        default_value => 0,
        doc => 'Remove the contaminates to a sub directory',
        is_input => 1,
    },
    screen_file => {
        is => 'Text',
        is_output => 1,
        doc => 'The output screen file.',
    },
    ],
};

#< Helps >#
sub help_brief {
    return 'Run contamnation screen on amplicon assembly reads'
}

sub help_detail {                           
    return <<EOS 
This command will run contamination screening on an amplicon assembly's data.  It can optionally remove the contaminates from the amplicon assembly, putting them in the screen directory of the amplicon assembly.
EOS
}

sub help_synopsis {
}

#< Command >#
sub sub_command_sort_position { 21; }

sub create {
    my $class = shift;
    
    my $self = $class->SUPER::create(@_)
        or return;

    # Verify DB
    unless ( $self->database ) {
        $self->error_message('Database is required');
        $self->delete;
        return;
    }

    my $xd_verify = Genome::Model::Tools::WuBlast::Xdformat::Verify->create(
        database => $self->database,
        db_type  => 'n',
    ) or return;
    unless ( $xd_verify->execute ) {
        $self->error_message('Can\'t verify db: '.$self->database);
        $self->delete;
        return;
    }

    unless ( $self->screen_file ) {
        my $time = UR::Time->now; 
        $time =~ s/ /\./; 
        $time =~ s/[\-\:]//g;
        $self->screen_file( $self->amplicon_assembly->contamination_dir."/screen.$time.txt" );
    }

    unlink $self->screen_file if -e $self->screen_file;
    
    return $self;
}

sub execute {
    my $self = shift;

    my $amplicon_assembly = $self->amplicon_assembly;
    my $fasta_file = $amplicon_assembly->create_amplicon_fasta_file_for_contamination_screening;
    
    my $contamination_screen =  Genome::Model::Tools::ContaminationScreen::3730->create(
        input_file => $fasta_file,
        output_file => $self->screen_file,
        database => $self->database,
    );

    $contamination_screen->execute
        or return;

    if ( $self->remove_contaminants ) {
        $amplicon_assembly->remove_contaminated_amplicons_by_reads_in_file(
            $self->screen_file
        ) or return;
    }

    return 1;
}

1;

#$HeadURL$
#$Id$
