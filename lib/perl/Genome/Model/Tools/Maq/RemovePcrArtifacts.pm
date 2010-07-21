package Genome::Model::Tools::Maq::RemovePcrArtifacts;

use Genome;

class Genome::Model::Tools::Maq::RemovePcrArtifacts {
    is => 'Genome::Model::Tools::Maq',
    has => [
        input => {
            type => 'String',
            doc => 'File path for input map',
        },
        keep => {
            type => 'String',
            doc => 'File path for map of unique reads',
        },
        remove => {
            type => 'String',
            doc => 'File path for map of removed reads',
        },
        identity_length => { 
            is => 'Integer', is_optional => 1, 
            doc => "Reads with the same sequence to this point are considered the same if at the same start site (NOT IMPLEMENTED!)." },
    ],
};

sub help_brief {
    "remove extra reads which are likely to be from the same fragment based on alignment start site, quality, and sequence",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt remove-pcr-artifacts --input orig.map --keep nodups.map --remove dups.map --sequence-identity-length 26
EOS
}

sub help_detail {                           
    return <<EOS 
This tool removes reads from a maq map file which are likely to be the result of PCR, rather than distinct DNA fragments.
It examines all reads at the same start site, selects the read which has the best data to represent the group based on length and alignment quality.

Optionally, groupis reads with a common sequence in the first n bases of the read and select the best read from that group.  (When unspecified, this value is effectively zero.)
EOS
}

sub execute {
    $DB::single = $DB::stopper;
    my $self = shift;
    my $in = $self->input;
    my $remove = $self->remove;
    my $keep = $self->keep;
    my $identity_length = $self->identity_length;
    unless (-e $in) {
        #hey, mimicking object layer messages isn't cool.
        #$self->error_message("Bad params!");
        $self->error_message("$in isn't a real file?");
        $self->usage_message($self->help_usage_complete_text);
        return;
    }
    
    # jit use so we don't compile when making the object for other reasons...
    require Genome::Model::Tools::Maq::RemovePcrArtifacts_C;
    my $result;
    if(defined $identity_length)
    {
        $result = Genome::Model::Tools::Maq::RemovePcrArtifacts_C::remove_dup_frags($in,$keep,$remove,$identity_length);
    }
    else
    {
        $result = Genome::Model::Tools::Maq::RemovePcrArtifacts_C::remove_dup_frags($in,$keep,$remove,0);
    }
    $result = !$result; # c -> perl

    $self->result($result);
    return $result;
}

1;

