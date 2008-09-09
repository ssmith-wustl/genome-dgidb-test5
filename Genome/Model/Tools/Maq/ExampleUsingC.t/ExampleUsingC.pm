package Genome::Model::Tools::Maq::ExampleUsingC;

use Genome;
class Genome::Model::Tools::Maq::ExampleUsingC {
    is => 'Command',
    has => [
        use_version => { is => 'Version', is_optional => 1, default_value => '0.6.3', doc => "Version of maq to use, if not the newest." }
    ],
};

sub help_brief {
    "Tools to run maq or work with its output files.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gt maq ...    
EOS
}

sub help_detail {                           
    return <<EOS 
More information about the maq suite of tools can be found at http://maq.sourceforege.net.
EOS
}

sub execute {
    $DB::single = $DB::stopper;
    my $self = shift;
    require Genome::Model::Tools::Maq::ExampleUsingC_C;
    my $fptr = Genome::Model::Tools::Maq::ExampleUsingC_C::test_ssmith_fptr();
    print "got address: $fptr\n";
    print "called function got return: " . Genome::Model::Tools::Maq::MapUtils::test_call_functionptr_with_string_param($fptr, "hello"),"\n";
    return 1;
}

1;

