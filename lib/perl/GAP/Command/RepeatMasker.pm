package GAP::Command::RepeatMasker;

use strict;
use warnings;

use Workflow;

use Bio::SeqIO;
use Bio::Tools::Run::RepeatMasker;


class GAP::Command::RepeatMasker {
    is => ['GAP::Command'],
    has => [
            input_file  => { 
                            is  => 'SCALAR', 
                            doc => 'input fasta file' 
                           },
            repeat_library => {
                               is  => 'SCALAR',
                               is_optional => 1,
                               doc => 'repeat library to pass to RepeatMasker', 
                              },
	    species	=> {
                               is  => 'SCALAR',
                               is_optional => 1,
                               doc => 'species inforamtion to pass to RepeatMasker', 
			   },
            output_file => { 
                            is          => 'SCALAR',
                            is_optional => 1,
                            doc         => 'output fasta file' 
                           },
    ], 
};

operation_io GAP::Command::RepeatMasker {
    input  => [ 'input_file', 'repeat_library', 'species' ],
    output => [ 'output_file' ]
};

sub sub_command_sort_position { 10 }

sub help_brief {
    "RepeatMask the contents of the input file and write the result to the output file";
}

sub help_synopsis {
    return <<"EOS"
EOS
}

sub help_detail {
    return <<"EOS"
Need documenation here.
EOS
}

sub execute {
    
    my $self = shift;
    my %params;

    my $input_file = $self->input_file();
    
    if ($input_file =~ /\.bz2$/) {
        $input_file = "bzcat $input_file |";
    }
  
    ##FIXME: The temp dir location should not be hardcoded.  At least not here.
    my $output_fh = File::Temp->new(
                                    'DIR'      => '/gscmnt/temp212/info/annotation/GAP_tmp',
                                    'SUFFIX'   => '.tmp',
                                    'TEMPLATE' => 'GAP_XXXXXXXX',
                                    'UNLINK'   => 0,
                                   );
   
    my $seqin  = Bio::SeqIO->new(-file => $input_file, -format => 'Fasta');
    my $seqout = Bio::SeqIO->new(-fh   => $output_fh,   -format => 'Fasta');

    my $input_seq = $seqin->next_seq();

    #my $masker = Bio::Tools::Run::RepeatMasker->new(lib => $self->repeat_library());
    my $masker;
    if ($self->repeat_library) {
    	$masker = Bio::Tools::Run::RepeatMasker->new(lib => $self->repeat_library);
    } elsif ($self->species) {
    	$masker = Bio::Tools::Run::RepeatMasker->new(species => $self->species);
    } 
    
    $masker->run($input_seq);

    my $masked_seq = $masker->masked_seq();     
 
    $seqout->write_seq($masked_seq);
   
    $output_fh->close();

    $self->output_file($output_fh->filename());
    
    return 1;
    
}

1;
