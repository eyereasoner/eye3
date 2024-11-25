% ------------------
% eye3 -- Jos De Roo
% ------------------
%
% See https://github.com/eyereasoner/eye3
%

:- use_module(library(iso_ext)).
:- use_module(library(terms)).

:- op(1150,xfx,=>).
:- op(1200,xfx,<=).

:- dynamic((=>)/2).
:- dynamic(answer/1).
:- dynamic(brake/0).
:- dynamic(proof/3).
:- dynamic(var_nr/1).

term_expansion((Head <= Body),(Head :- Body)).

version_info('eye3 v1.2.1 (2024-11-26)').

% main goal
main :-
    bb_put(closure,0),
    bb_put(limit,-1),
    (   (_ => _)
    ->  write(':- op(1150,xfx,=>).'),
        nl,
        nl
    ;   version_info(Version),
        write(Version),
        nl
    ),
    run,
    halt(0).

% run eye3 abstract machine
%
% 1/ select rule P => C
% 2/ prove P and if it fails backtrack to 1/
% 3/ if C = true assert answer(P)
%    else if C = false stop with return code 2
%    else if ~C assert C, retract brake
% 4/ backtrack to 2/ and if it fails go to 5/
% 5/ if brake
%       if not stable start again at 1/
%       else write all answers as P => true and stop
%    else assert brake and start again at 1/
%
run :-
    (   (Prem => Conc),     % 1/
        copy_term((Prem => Conc),Rule),
        labelvars(Rule),
        Prem,               % 2/
        (   Conc = true     % 3/
        ->  labelvars(Prem),
            (   \+answer(Prem)
            ->  assertz(answer(Prem))
            ;   true
            )
        ;   (   Conc = false
            ->  write('% inference fuse, return code 2'),
                nl,
                writeq(Prem),
                write(' => false.'),
                nl,
                halt(2)
            ;   \+Conc,
                labelvars(Conc),
                astep(Conc),
                assertz(proof(Rule,Prem,Conc)),
                retract(brake)
            )
        ),
        fail                % 4/
    ;   (   brake           % 5/
        ->  (   bb_get(closure,Closure),
                bb_get(limit,Limit),
                Closure < Limit,
                NewClosure is Closure+1,
                bb_put(closure,NewClosure),
                run
            ;   answer(Prem),
                writeq(Prem),
                write(' => true.'),
                nl,
                fail
            ;   (   proof(_,_,_)
                ->  nl,
                    write('% proof'),
                    nl,
                    proof(Rule,Prem,Conc),
                    writeq(proof(Rule,Prem,Conc)),
                    nl,
                    fail
                ;   true
                )
            ;   true
            )
        ;   assertz(brake),
            run
        )
    ).

% create witnesses
labelvars(Term) :-
    (   retract(var_nr(Current))
    ->  true
    ;   Current = 0
    ),
    numbervars(Term,Current,Next),
    assertz(var_nr(Next)).

% assert new step
astep((B,C)) :-
    astep(B),
    astep(C).
astep(A) :-
    (   \+A
    ->  assertz(A)
    ;   true
    ).

% stable(+Level)
% fail if the deductive closure at Level is not yet stable
stable(Level) :-
    bb_get(limit,Limit),
    (   Limit < Level
    ->  bb_put(limit,Level)
    ;   true
    ),
    bb_get(closure,Closure),
    Level =< Closure.
