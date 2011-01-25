package Genome::Model::Tools::DetectVariants2::Strategy;

use strict;
use warnings;

use Genome;
use Parse::RecDescent;

# grammar for parsing strategy rules
my $grammar = q{
    startrule: combination end
        { $item[1]; }
    | <error>

    end: /^\Z/

    combination: intersection
                { $item[1]; }
    | union
                { $item[1]; }
    | single
                { $item[1]; }
    | <error>
    
    parenthetical: "(" combination ")"
                { $item[2]; }
                
    intersection: single "intersect" combination
                { $return = { intersect => [$item[1], $item[3] ] }; }
    
    union: single "union" combination
                { $return = { union => [ $item[1], $item[3] ] }; }
    
    single: parenthetical
                { $item[1]; }
    | strategy
                { $item[1]; }
    
    strategy: program_spec "filtered by" filter_list
                { $return = { detector => {%{$item[1]}, filters => $item[3]} }; }
    | program_spec 
                { $return = { detector => {%{$item[1]}, filters => []} }; }
    | <error>

    filter_list: program_spec "," filter_list
                { $return = [$item[1], @{$item[3]}]; }
    | program_spec
                { $return = [$item[1]]; }

    word: /([\w\.-]|\\\\)+/ { $return = $item[1]; }

    valid_subpackage: "somatic"
                { $return = $item[1]; }

    name: valid_subpackage word
                { $return = "$item[1] $item[2]"; }
    | word
                { $return = $item[1]; }
    | <error>

    version: word { $return = $item[1]; }
    | <error>

    params: {
                my $txt = extract_bracketed($text, '[]');
                $txt =~ s/^\[(.*)\]$/$1/;
                $txt=~ s/\\\\([\[\]])/$1/g;
                $return = $txt;
            } 

    program_spec: name version params
                { $return = {
                    name => $item[1],
                    version => $item[2],
                    params => $item[3],
                    };
                }
    | name version
                { $return = {
                    name => $item[1],
                    version => $item[2],
                    params => '',
                    };
                }
};


class Genome::Model::Tools::DetectVariants2::Strategy {
    is => ['UR::Value'],
    id_by => 'id',
    has => [
        id => { is => 'Text' },
    ],
    doc => 'This class represents a variant detection strategy. It specifies a variant detector, its version and parameters, as well as any filtering to be done.'
};

sub __errors__ {
    my $self = shift;
    my @tags = $self->SUPER::__errors__(@_);

    my $tree = $self->tree;
    push @tags, $self->{_last_error} if exists $self->{_last_error};
    unless ($tree) {
        push @tags, UR::Object::Tag->create(
            type => 'error',
            properties => ['id'],
            desc => "Failed to create detector strategy from id string " . $self->id,
            );
    }

    $self->validate($tree);

    return @tags;
}

sub create {
    my $class = shift;
    return $class->SUPER::create(@_);
}

sub parse {
    my ($self, $str) = @_;
    my $parser = Parse::RecDescent->new($grammar)
        or die "Failed to create parser from grammar";
    my $tree = $parser->startrule($str);
    $self->_add_class_info($tree) if $tree;
    return $tree;
}

sub _set_last_error {
    my ($self, $msg) = @_;
    $self->{_last_error} = UR::Object::Tag->create(
        type => 'error',
        properties => [],
        desc => $msg,
    );
}

sub tree {
    my $self = shift;

    # already computed it
    return $self->{_tree} if defined $self->{_tree};

    eval { $self->{_tree} = $self->parse($self->id); };
    if ($@) {
        $self->_set_last_error($@);
        return;
    }

    return $self->{_tree};
}

sub _add_class_info {
    my ($self, $tree) = @_;
    my @keys = keys %$tree;
    for my $key (@keys) {
        if ($key eq 'detector') {
            my $name = $tree->{$key}->{name};
            my $class = $self->detector_class($name);
            $tree->{$key}->{class} = $class;
            # FIXME combine this code with the below
            my $number_of_filters = scalar @{$tree->{$key}->{filters}};
            next unless $number_of_filters > 0;
            for my $index (0..$number_of_filters - 1) {
                my $name = @{$tree->{$key}->{filters}}[$index]->{name};
                my $class = $self->filter_class($name);
                @{$tree->{$key}->{filters}}[$index]->{class} = $class;
            }
        } elsif (ref $tree->{$key} eq 'ARRAY') {
            ($self->_add_class_info($_)) for (@{$tree->{$key}});
        }
    }
}

sub detector_class {
    my $self = shift;
    my $detector = shift;
    
    # Convert things like "hi foo-bar" to "Hi::FooBar"
    $detector = join("::", 
        map { join('', map { ucfirst(lc($_)) } split(/-/, $_))
            } split(' ', $detector));
    
    my $detector_class_base = 'Genome::Model::Tools::DetectVariants2';
    my $detector_class = join('::', ($detector_class_base, $detector));
    
    return $detector_class;
}

# TODO merge this with the above method, probably. The only difference is the ::Filter part.
sub filter_class {
    my $self = shift;
    my $filter = shift;
    
    # Convert things like "hi foo-bar" to "Hi::FooBar"
    $filter = join("::", 
        map { join('', map { ucfirst(lc($_)) } split(/-/, $_))
            } split(' ', $filter));
    
    my $filter_class_base = 'Genome::Model::Tools::DetectVariants2::Filter';
    my $filter_class = join('::', ($filter_class_base, $filter));
    
    return $filter_class;
}

sub validate {
    my ($self, $tree) = @_;
    #return;
    #$DB::single=1;

    my @keys = keys %$tree;
    for my $key (@keys) {
        if ($key eq 'detector') {
            ## Check detector class and params
            my $class = $tree->{$key}->{class};
            my $version = $tree->{$key}->{version};
            unless($self->is_class_valid($class)){
                die "could not find class ".$class."\n";
            }

            ## Check filters that belong to this detector
            for my $filter (@{$tree->{$key}->{filters}}) {
                my $filter_class = $filter->{class};
                my $filter_version = $filter->{version};
                unless($self->is_class_valid($filter_class)){
                    die "could not find class ".$filter_class."\n";
                }
            }

        } elsif (ref $tree->{$key} eq 'ARRAY') {
            for my $subtree ( @{$tree->{$key}} ) {
                $self->validate($subtree);
            }
        }
    }
}

sub is_class_valid {
    my $self = shift;
    my $class = shift;
    my $result;
    eval {
        $result = $class->__meta__;
    };
    if($@){
        return 0;
    }
    return 1;
}

1;
