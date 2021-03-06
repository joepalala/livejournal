package LJ::Console::Command::Help;

use strict;
use base qw(LJ::Console::Command);
use Carp qw(croak);
use Class::Autouse qw(
                      Text::Wrap
                      LJ::ModuleLoader
                      );

my @CLASSES = LJ::ModuleLoader->module_subclasses("LJ::Console::Command");
foreach my $class (@CLASSES) {
    eval "use $class";
    die "Error loading class '$class': $@" if $@;
}

sub cmd { "help" }

sub desc { "Get help on console commands." }

sub args_desc { [
                  'command' => "A command to get help on. If omitted, prints help for all commands.",
                  ] }

sub usage { '[ <command> ]' }

sub requires_remote { 0 }

sub can_execute { 1 }

sub execute {
    my ($self, $command, @args) = @_;

    return $self->error("This command takes at most one argument. Consult the reference.")
        unless scalar(@args) == 0;

    eval { Text::Wrap->can("autouse"); };
    $Text::Wrap::columns = 72;

    my $pr = sub {
        my $text = shift;
        $self->info($_) foreach (split(/\n/, $text));
    };

    unless ($command) {
        foreach my $class (sort { $a->cmd cmp $b->cmd } @CLASSES) {
            next if $class->is_hidden;
            next unless $class->can_execute;
            my $cmd = $class->cmd;
            my $desc = $class->desc;
            my $indent = length($cmd) + 2;
            my $text = Text::Wrap::wrap('',' ' x $indent,"$cmd: $desc");
            $pr->($text);
        }
        return 1;
    }

    my $foundclass;
    foreach my $class (@CLASSES) {
        next if $class->is_hidden;
        if ($command eq $class->cmd) {
            $foundclass = $class;
        }
    }
    return $self->error("Command '$command' does not exist here.")
        unless $foundclass;

    return $self->error("You are not authorized to run '$command'")
        unless $foundclass->can_execute;

    $pr->($foundclass->cmd . " " . $foundclass->usage);
    $pr->(Text::Wrap::wrap('  ', '  ', $foundclass->desc));

    if ($foundclass->args_desc) {
        $pr->("  --------");
        my @des = @{$foundclass->args_desc || []};
        while (my ($arg, $des) = splice(@des, 0, 2)) {
            $pr->("  $arg");
            $pr->(Text::Wrap::wrap('    ', '    ', $des));
        }
    }

    return 1;
}

1;
