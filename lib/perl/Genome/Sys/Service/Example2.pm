use Genome;

class Genome::Sys::Service::Example2 {
    is => ['UR::Singleton','Genome::Sys::Service'],
    has_constant => [
        foo => { default_value => "FOO" },
    ],
    doc => ""
};


