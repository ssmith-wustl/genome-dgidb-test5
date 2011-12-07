use Genome;

class Genome::Sys::Service::Example1 {
    is => ['Genome::Sys::Service','UR::Singleton'],
    has_constant => [
        foo => { default_value => "FOO" },
    ],
    doc => ""
};

1;

