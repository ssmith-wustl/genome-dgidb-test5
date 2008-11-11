package Genome::Command;

use strict;
use warnings;

use Genome;

use Data::Dumper;
require File::Basename;

class Genome::Command {
    is => 'Command',
    english_name => 'genome command',
};

our %SUB_COMMAND_CLASSES = (
    model => 'Genome::Model::Command',
    'processing-profile' => 'Genome::ProcessingProfile::Command',
    tools => 'Genome::Model::Tools',
);
for my $class ( values %SUB_COMMAND_CLASSES ) {
    eval("use $class;");
    die $@ if $@; 
}

sub command_name {
    my $class = ref($_[0]) || $_[0];
    return $class->SUPER::command_name unless $class eq __PACKAGE__;
    return 'genome';
}

sub command_name_brief {
    my $class = ref($_[0]) || $_[0];
    return $class->SUPER::command_name_brief unless $class eq __PACKAGE__;
    return 'genome';
}

sub is_sub_command_delegator {
    return 1;
}

sub sub_command_classes {
    return values %SUB_COMMAND_CLASSES;
}

sub class_for_sub_command {
    my $class = ref($_[0]) || $_[0];
    #return $class->SUPER::class_for_sub_command unless $class eq __PACKAGE__;
    return $SUB_COMMAND_CLASSES{$_[1]};
}
  
1;

__END__

sub _genome_command_sub_class_types {
    return (qw/ model processing_profile /);
}

sub _genome_command_sub_class_types_camel_cased {
    return map { join('', map { ucfirst } split(/\_/)) } _genome_command_sub_class_types();
}

sub _genome_command_sub_class_commands {
    return map { s#\_#\-#g } _genome_command_sub_class_types();
}

sub _camel_case_to_command {
    my ($string) = @_;

    my @words = $string =~ /([A-Z](?:[A-Z]*(?=$|[A-Z][a-z])|[a-z]*))/g;
    return join('-', map { lc } @words);
}

sub command_name {
    my $self = shift;
    my $class = ref($self) || $self;
    my ($sub_class) = grep { $class =~ m#$_#i } _genome_command_sub_class_types_camel_cased()
        or return $self->SUPER::command_name(@_);
    return sprintf('genome %s', _camel_case_to_command($sub_class));
}

sub sub_command_dirs {
    my $class = ref($_[0]) || $_[0];

    my $dir = $class->SUPER::sub_command_dirs;
    
    return $dir unless $class eq __PACKAGE__;

    print Dumper({dir=>$dir});
    $dir =~ s#/Command##;
    
    return map { sprintf('%s/%s/Command/', $dir, $_) } _genome_command_sub_class_types_camel_cased();
}

sub sub_command_classes {
    my $class = shift;

    return $class->SUPER::sub_command_classes unless $class eq __PACKAGE__;
    print Dumper([$class, [caller]]);

    return map { sprintf('Genome::%s::Command', $_) } _genome_command_sub_class_types_camel_cased();
}

sub class_for_sub_command {
    my $class = ref($_[0]) || $_[0];

    return $_[0]->SUPER::class_for_sub_command(@_) unless $class eq __PACKAGE__;

    my ($type) = grep { $_[1] eq $_ } _genome_command_sub_class_commands;
    return unless $type;

    return sprintf$_[0]->SUPER::class_for_sub_command(@_) unless $class eq __PACKAGE__;
    return sprintf('Genome::%s::Command', join('', map { ucfirst } split(/\_/, $type)));
}
  
sub sub_command_names {
    my $class = shift;
    print Dumper({$class=>[caller]});
    my @sub_command_classes = $class->sub_command_classes;
    my @sub_command_names= map { $_->command_name_brief } @sub_command_classes;
    return @sub_command_names;
}

1;

#$HeadURL$
#$Id$
