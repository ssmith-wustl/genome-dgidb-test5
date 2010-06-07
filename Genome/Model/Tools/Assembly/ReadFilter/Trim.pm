package Genome::Model::Tools::Assembly::ReadFilter::Trim;

use strict;
use warnings;

use Genome;            

class Genome::Model::Tools::Assembly::ReadFilter::Trim {
    is => 'UR::Object',
    has => 
    [
        trim_length => {
            is => 'Number',
            doc => 'the number of bases to remove',
            #default_value => 20,
        }    
     ],
};

sub trim
{
    my ($self, $seq) = @_;
    my $trim_length = $self->trim_length;
    #TODO: check for sane trim length
    my $bases = $seq->seq;
    my @quals = @{$seq->qual};
    my $length = length($bases) - $trim_length;
    $length = 0 if($length<0);
    @quals = splice @quals,0,$length;
    $bases = substr($bases,0,$length);
    $seq->seq($bases);
    $seq->qual(\@quals);
    
    return $seq;
    
}

#sub sub_command_sort_position { 15 }



1;

