package Genome::Model::Tools::Maq::GetIntersect;

use strict;
use warnings;

use Genome;
use Command;

class Genome::Model::Tools::Maq::GetIntersect {
    is => 'Genome::Model::Tools::Maq',
    has => [
        input => {
            type => 'String',
            doc => 'File path for input map',
        },
        output => {
            type => 'String',
            doc => 'File path for output map',
        },
        snpfile => {
            type => 'String',
            doc => 'File path for file with seqid/positions',
        },
        justname => {
            #type => 'Integer',
            is_optional => 1,
            doc => 'File path for file with seqid/positions',
        }
    ],
};

sub help_brief {
    "grab reads that intersect seqid/positions",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt get-intersect --input=in.map --snpfile=snpfile --output=out.map
EOS
}

sub help_detail {                           
    return <<EOS 
This tool removes reads that do not intersect positions in the provided snp file.
EOS
}

sub execute {
    $DB::single = 1;#$DB::stopper;
    my $self = shift;
    my $in = $self->input;
    my $output = $self->output;
    my $snp = $self->snpfile;
    unless ($in and $output and $snp and -f $snp) {
        $self->error_message("Bad params!");
        $self->usage_message($self->help_usage_complete_text);
        return;
    }
    
    # jit use so we don't compile when making the object for other reasons...
    require Genome::Model::Tools::Maq::GetIntersect_C;
    my $result;
    if($self->justname)
    {
        $result = Genome::Model::Tools::Maq::GetIntersect_C::write_seq_ov($in,$snp, $output,int($self->justname));
    }
    else
    {
            $result = Genome::Model::Tools::Maq::GetIntersect_C::write_seq_ov($in,$snp, $output,0);
    }
    $result = !$result; # c -> perl

    $self->result($result);
    return $result;
}

1;

