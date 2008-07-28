package Genome::Model::Tools::Maq;

use strict;
use warnings;

use above "Genome";                         # >above< ensures YOUR copy is used during development

use File::Basename;

class Genome::Model::Tools::Maq {
    is => 'Command',
    has => [
        use_version => { is => 'Version', is_optional => 1, default_value => '0.6.3', doc => "Version of maq to use" }
    ],
};

sub sub_command_sort_position { 12 }

sub help_brief {
    "Tools to run maq or work with its output files.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
genome-model tools maq ...    
EOS
}

sub help_detail {                           
    return <<EOS 
More information about the maq suite of tools can be found at http://maq.sourceforege.net.
EOS
}


sub c_linkage_class {
    my $self = shift;

$DB::single = $DB::stopper;
    my $version = $self->use_version;
    $version =~ s/\./_/g;

    my $class_to_use = __PACKAGE__ . "::CLinkage$version";
  
    #eval "use above '$class_to_use';";
    eval "use $class_to_use;";
    if ($@) {
        $self->error_message("Failed to use $class_to_use: $@");
        return undef;
    }

    return $class_to_use;
}

1;

