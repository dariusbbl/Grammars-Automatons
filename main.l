/* Bobelniceanu Darius-Andrei - 331CC */

%{
#include <iostream>
#include <string>
#include <vector>
#include <stack>
#include <unordered_map>

extern "C"
{
    extern int yylex(void);
}

using namespace std;

// Tine cont de numarul de comentarii multi-line deschide, pentru cazuri ca "/* /* */ */"
int comments_nested = 0;

typedef struct {
    string name; // numele variabilei
    vector<char> domain; // valorile pe care le poate lua variabila 
} Variable;
vector<Variable> variables;
// Stochez temporar variabilele citite aici pana le termin de citit integral
Variable temp_variable;

void reset_temp_variable() {
    temp_variable.name = "";
    temp_variable.domain.clear();
}

int find_variable(string name) {
    for (int i = 0; i < variables.size(); i++) {
        if (variables[i].name == name) {
            return i;
        }
    }
    return -1;
}

// Structuri pentru date care nu pot fi scrise direct/sunt necesare mai tarziu
typedef struct {
    bool deterministic; // automat determinist (true/false)
    vector<char> alphabet; // literele alfabetului 
    vector<string> states; // multimea starilor automatului
    vector<string> final_states; // multimea starilor finale 
    // Stocheaza numarul tranzitiilor pentru fiecare grupare stare + caracter
    // Exemplu: q0 -> (a -> q1; a -> q2;) => transitions["q0"]['a'] = 2
    // Sau q0 -> (a -> q1; b -> q2;) => transitions["q0"]['a'] = 1 si transitions["q0"]['b'] = 1
    unordered_map<string, unordered_map<char, int>> transitions; // map pentru evidenta tranzitiilor
    // Stocheaza literele/domeniul variabilelor din tranzitie pana ajung la starea finala
    // Exemplu: a, b -> q2 => last_letters = {a, b} sau x -> q2 => last_letters = {a, b}
    vector<char> last_letters;
    // Starea initiala a tranzitiilor dintr-un bloc
    string current_initial;
    // Cate variabile din vector sunt locale
    int my_variables;
} AutomatonData;
AutomatonData automaton;

// resetarea variabilelor automatului pentru procesarea altuia
void reset_automaton_data() {
    automaton.deterministic = true; // presupunem ca automatul este determinist
    automaton.alphabet.clear();
    automaton.states.clear();
    automaton.final_states.clear();
    automaton.transitions.clear();
    automaton.last_letters.clear();
    automaton.my_variables = 0;
}

typedef enum {
    GN = 1, // Nerestrictionata
    GDC = 2, // Dependenta de context
    GIC = 3, // Independenta de context
    GR = 4 // Regulata
} Grammars;

typedef struct {
    Grammars type; // tipul gramaticii conform enum-ului (GN, GDC, GIC, GR)
    vector<char> alphabet; // alfabetul gramaticii
    int nonterminal_count; // numarul de neterminali
    int terminal_count; // numarul de terminali
    int start_size; // dimensiunea partii stangi a sagetii de la productie
    int production_rules; // numarul total de reguli de productie
    // Ultimul simbol citit, pentru cazurile in care o productie se termina cu "e"
    string last_read;
    int my_variables; // cate variabile locale are gramatica
} GrammarData;
GrammarData grammar;

// resetarea variabilelor gramaticii pentru procesarea alteia
void reset_grammar_data() {
    grammar.type = GR; // plecam de la presupunerea ca este regulata 
    // si pe masura ce observam incalcarea regulilor, schimbam tipul
    grammar.alphabet.clear();
    grammar.nonterminal_count = 0;
    grammar.terminal_count = 0;
    grammar.start_size = 0;
    grammar.production_rules = 0;
    grammar.last_read = "";
    grammar.my_variables = 0;
}

// resetarea variabilelor productiilor din gramatica pentru procesarea uneia noi
void reset_grammar_production_data() {
    grammar.nonterminal_count = 0;
    grammar.terminal_count = 0;
    grammar.start_size = 0;
}

%}

%option stack

%x IN_COMMENT VARIABLE IN_VARIABLE L_VARIABLE L_IN_VARIABLE
%s AUTOMATON_MAIN A_ALPHABET A_STATES A_FINAL_STATES A_INITIAL_STATE A_TRANSITIONS A_TRANSITIONS_END
%s GRAMMAR_MAIN G_NONTERMINALS G_ALPHABET G_START_SYMBOL G_PRODUCTIONS G_PRODUCTIONS_END

whitespace [ \t]
newline \n
comm_singleline "%"
comm_multiline_start "/*"
comm_multiline_end "*"+"/"
domain_start {whitespace}*"::"{whitespace}*"\{"
domain_start_variable {whitespace}*"::="{whitespace}*"\{"
domain_end "\}"{whitespace}*";"
automaton_end "\)"{whitespace}*";;"
grammar_end "\)"{whitespace}*";;"

string [a-zA-Z0-9_]+
nonterminal [A-Z][a-zA-Z0-9_]*
variable_definition "variable"
automaton_definition {whitespace}*"::="{whitespace}*"FiniteAutomaton"({whitespace}|{newline})*"\("
grammar_definition {whitespace}*"::="{whitespace}*"Grammar"({whitespace}|{newline})*"\("
alphabet_definition "alphabet"{domain_start}
states_definition "states"{domain_start}
final_states_definition "final_states"{domain_start}
initial_state_definition "initial_state"{whitespace}*"::"
nonterminals_definition "nonterminals"{domain_start}
start_symbol_definition "start_symbol"{whitespace}*"::"

%%

<*>({newline}|{whitespace}) {
    // "\n", " " si "\t" sunt ignorate implicit peste tot
}

<*>{comm_singleline}.* { /* "." face match si ignora orice pana la newline */ }
<*>{comm_multiline_start} {
    if (comments_nested == 0) {
        comments_nested++;
        BEGIN(IN_COMMENT);
    } else {
        comments_nested++;
    }
}
<IN_COMMENT>{
    {comm_multiline_end} {
        if (comments_nested == 1) {
            comments_nested--;
            BEGIN(INITIAL);
        } else {
            comments_nested--;
        }
    }
    "*"+ ;
    . { /* Ignora alte caractere; newline e eliminat de prima regula cu "<*>" */ }
}

<INITIAL>{
    {string}/{automaton_definition} {
        // Cu look-ahead ca sa citesc strict numele automatului
        reset_automaton_data();
        cout << "Automat cu numele: \"" << yytext << "\"" << endl;
        yy_push_state(AUTOMATON_MAIN);
    }
    {string}/{grammar_definition} {
        reset_grammar_data();
        cout << "Gramatica cu numele: \"" << yytext << "\"" << endl;
        yy_push_state(GRAMMAR_MAIN);
    }
    {variable_definition} {
        reset_temp_variable();
        yy_push_state(VARIABLE);
    }
}

<VARIABLE>{
    {string} {
        temp_variable.name = yytext;
    }
    {domain_start_variable} {
        yy_push_state(IN_VARIABLE);
    }
}

<IN_VARIABLE>{
    , ; // ignor virgulele
    [a-z0-9] {
        temp_variable.domain.push_back(yytext[0]);
    }
    {domain_end} {
        variables.push_back(temp_variable);
        
        cout << "== Variabila globala: ==" << endl;
        cout << "-> Numele ei: " << temp_variable.name << endl;
        cout << "-> Domeniul ei: { ";
        for (int i = 0; i < temp_variable.domain.size(); i++) {
            if (i != 0) {
                cout << ", ";
            }
            cout << temp_variable.domain[i];
        }
        cout << " }" << endl << endl;

        // De 2 ori pentru ca am si "VARIABLE" si "IN_VARIABLE" pe stack
        yy_pop_state();
        yy_pop_state();
    }
}

<L_VARIABLE>{
    {string} {
        // Variabile locale -> Aceleasi operatii ca la variabilele globale, doar ca aici nu le afisez direct dupa citire
        temp_variable.name = yytext;
    }
    {domain_start_variable} {
        // Formatul de afisare e in AUTOMATON_MAIN sau in GRAMMAR_MAIN
        yy_push_state(L_IN_VARIABLE);
    }
}

<L_IN_VARIABLE>{
    , ;
    {string} {
        temp_variable.domain.push_back(yytext[0]);
    }
    {domain_end} {
        variables.push_back(temp_variable);
        yy_pop_state();
        yy_pop_state();
    }
}

<AUTOMATON_MAIN>{
    {automaton_definition} ; // ignor " ::= FiniteAutomaton "
    {alphabet_definition} {
        yy_push_state(A_ALPHABET);
    }
    {states_definition} {
        yy_push_state(A_STATES);
    }
    {final_states_definition} {
        yy_push_state(A_FINAL_STATES);
    }
    {initial_state_definition} {
        yy_push_state(A_INITIAL_STATE);
    }
    {variable_definition} {
        reset_temp_variable();
        automaton.my_variables++;
        yy_push_state(L_VARIABLE);
    }
    {string} {
        // Orice alt string in afara de cazurile de mai sus e inceput de tranzitie
        // ex: q0 -> ...
        if (automaton.transitions.size() == 0) { 
            // daca este prima tranzitie
            cout << "Tranzitiile automatului: " << endl;
        }
        automaton.current_initial = yytext; // salvez starea de inceput a tranzitiei
        yy_push_state(A_TRANSITIONS);
    }
    {automaton_end} {
        // Dinamic am putut verifica doar sa nu fie mai multe tranzitii cu aceeasi combinatie
        // stare + litera, dar nu am verificat daca nu sunt deloc tranzitii pentru acea pereche
        // verificare determinism automat
        for (string state : automaton.states) {
            for (char letter : automaton.alphabet) {
                if (automaton.transitions.find(state) == automaton.transitions.end() || 
                    automaton.transitions[state].find(letter) == automaton.transitions[state].end() ||
                    automaton.transitions[state][letter] == 0) {
                    automaton.deterministic = false;
                }
            }
        }
        if (automaton.deterministic) {
            cout << "Automatul este de tip DETERMINIST" << endl;
        } else {
            cout << "Automatul este de tip NEDETERMINIST" << endl;
        }
        // Variabilele locale se scriu abia la final de automat
        for (int i = 0; i < automaton.my_variables; i++) {
            cout << "== Variabila locala: ==" << endl;
            cout << "-> Numele ei: " << variables[variables.size() - automaton.my_variables + i].name << endl;
            cout << "-> Domeniul ei: { ";
            for (int j = 0; j < variables[variables.size() - automaton.my_variables + i].domain.size(); j++) {
                if (j != 0) {
                    cout << ", ";
                }
                cout << variables[variables.size() - automaton.my_variables + i].domain[j];
            }
            cout << " }" << endl;
        }
        for (int i = 0; i < automaton.my_variables; i++) {
            variables.pop_back();
        }
        cout << endl;
        yy_pop_state();
    }
}

<GRAMMAR_MAIN>{
    {grammar_definition} ; // ignor " ::= Grammar "
    {nonterminals_definition} {
        yy_push_state(G_NONTERMINALS);
    }
    {alphabet_definition} {
        yy_push_state(G_ALPHABET);
    }
    {start_symbol_definition} {
        yy_push_state(G_START_SYMBOL);
    }
    {variable_definition} {
        reset_temp_variable();
        grammar.my_variables++;
        yy_push_state(L_VARIABLE);
    }
    {nonterminal} {
        // Orice alt string in afara de cazurile de mai sus e inceput de regula de productie
        reset_grammar_production_data();
        grammar.nonterminal_count++;
        yy_push_state(G_PRODUCTIONS);
    }
    [a-z0-9] {
        // Ca mai sus, doar ca pentru terminale (cele din alfabet), la regula de productie
        reset_grammar_production_data();
        grammar.terminal_count++;
        yy_push_state(G_PRODUCTIONS);
    }
    {grammar_end} {
        // Numarul de reguli si tipul gramaticii il pot sti sigur abia la finalul citirii gramaticii
        cout << "Gramatica are " << grammar.production_rules << " reguli de productie" << endl;
        if (grammar.type == GN) {
            cout << "Gramatica este de tip NERESTRICTIONAT" << endl;
        } else if (grammar.type == GDC) {
            cout << "Gramatica este de tip DEPENDENTA DE CONTEXT" << endl;
        } else if (grammar.type == GIC) {
            cout << "Gramatica este de tip INDEPENDENTA DE CONTEXT" << endl;
        } else if (grammar.type == GR) {
            cout << "Gramatica este de tip REGULAT" << endl;
        }
        for (int i = 0; i < grammar.my_variables; i++) {
            cout << "== Variabila locala: ==" << endl;
            cout << "-> Numele ei: " << variables[variables.size() - grammar.my_variables + i].name << endl;
            cout << "-> Domeniul ei: { ";
            for (int j = 0; j < variables[variables.size() - grammar.my_variables + i].domain.size(); j++) {
                if (j != 0) {
                    cout << ", ";
                }
                cout << variables[variables.size() - grammar.my_variables + i].domain[j];
            }
            cout << " }" << endl;
        }
        cout << endl;

        for (int i = 0; i < grammar.my_variables; i++) {
            variables.pop_back();
        }
        yy_pop_state();
    }
}

<A_ALPHABET>{
    , ; // ignor virgulele
    {string} {
        // Daca e "variable" trebuie expandat domeniul
        int idx = find_variable(yytext);
        if (idx == -1) {
            // daca string-ul nu a fost gasit drept variabila,
            // adaugam caracterul in alfabet
            automaton.alphabet.push_back(yytext[0]);
        } else {
            // adaugam caracterele din domeniul variabilei
            for (int i = 0; i < variables[idx].domain.size(); i++) {
                automaton.alphabet.push_back(variables[idx].domain[i]);
            }
        }
    }
    {domain_end} {
        cout << "Alfabetul automatului: { ";
        for (int i = 0; i < automaton.alphabet.size(); i++) {
            if (i != 0) {
                cout << ", ";
            }
            cout << automaton.alphabet[i];
        }
        cout << " }" << endl;
        yy_pop_state();
    }
}

<A_STATES>{
    , ;
    {string} {
        automaton.states.push_back(yytext);
    }
    {domain_end} {
        // Trebuie scris doar numarul lor, nu si pe ele in sine
        cout << "Numarul de stari: " << automaton.states.size() << endl;
        yy_pop_state();
    }
}

<A_FINAL_STATES>{
    , ;
    {string} {
        automaton.final_states.push_back(yytext);
    }
    {domain_end} {
        cout << "Starile finale: { ";
        for (int i = 0; i < automaton.final_states.size(); i++) {
            if (i != 0) {
                cout << ", ";
            }
            cout << automaton.final_states[i];
        }
        cout << " }" << endl;
        yy_pop_state();
    }
}

<A_INITIAL_STATE>{
    {string} {
        cout << "Starea initiala: " << yytext << endl;
    }
    ; {
        yy_pop_state();
    }
}

<A_TRANSITIONS>{
    "->"{whitespace}*"\(" ; // ignor sageata si paranteza de la stare de la input
    , ;

    [a-z0-9] { // pentru caracterele din alfabet
        int idx = find_variable(yytext);
        if (idx == -1) { // nu e variable
            automaton.transitions[automaton.current_initial][yytext[0]]++;
            // Verific pe loc daca mai exista o tranzitie cu aceeasi combinatie stare + litera
            if (automaton.transitions[automaton.current_initial][yytext[0]] > 1) {
                automaton.deterministic = false;
            }
            // De asemenea, e-tranzitiile fac automatul nedeterminist, deci verific si asta
            if (yytext[0] == 'e') {
                automaton.deterministic = false;
            }
            automaton.last_letters.push_back(yytext[0]);
        } else {
            // este variabila -> trebuie sa adaugam la domeniu
            for (int i = 0; i < variables[idx].domain.size(); i++) {
                automaton.transitions[automaton.current_initial][variables[idx].domain[i]]++;
                if (automaton.transitions[automaton.current_initial][variables[idx].domain[i]] > 1) {
                    automaton.deterministic = false;
                }
                // adaugam caracterele de input ca litere pentru tranzitii
                automaton.last_letters.push_back(variables[idx].domain[i]);
            }
        }
    }
    {string} {
        // Daca e variabila poate sa nu fie neaparat in [a-z0-9], ci sa fie string mai lung
        int idx = find_variable(yytext);
        if (idx == -1) {
            cout << "EROARE: Variabila necunoscuta: " << yytext << endl;
        } else {
            // la fel ca mai sus
            for (int i = 0; i < variables[idx].domain.size(); i++) {
                automaton.transitions[automaton.current_initial][variables[idx].domain[i]]++;
                if (automaton.transitions[automaton.current_initial][variables[idx].domain[i]] > 1) {
                    automaton.deterministic = false;
                }
                automaton.last_letters.push_back(variables[idx].domain[i]);
            }
        }
    }
    "->" {
        // Acum trebuie sa vad in ce stare se duc literele citite, adica ce e dupa "->"
        yy_push_state(A_TRANSITIONS_END);
    }
    "\)"{whitespace}*";" {
        yy_pop_state();
    }
}

<A_TRANSITIONS_END>{
    {string} {
        // Scriu tranzitiile pentru toate literele dinaintea sagetii
        for (int i = 0; i < automaton.last_letters.size(); i++) {
            cout << "-> m(" << automaton.current_initial << ", " << automaton.last_letters[i] << ") = " << yytext << endl;
        }
        automaton.last_letters.clear();
    }
    ";" {
        yy_pop_state();
    }
}

<G_NONTERMINALS>{
    , ;
    {string} ;
    {domain_end} {
        // Nu se cere nimic cu astia la output, ii ignor complet
        yy_pop_state();
    }
}

<G_ALPHABET>{
    , ; // ignor virgule
    {string} {
        // Exact ca la alfabetul automatelor
        int idx = find_variable(yytext);
        if (idx == -1) {
            grammar.alphabet.push_back(yytext[0]);
        } else {
            // adaug toate caracterele din domeniul variabilei
            for (int i = 0; i < variables[idx].domain.size(); i++) {
                grammar.alphabet.push_back(variables[idx].domain[i]);
            }
        }
    }
    {domain_end} {
        cout << "Alfabetul gramaticii: { ";
        for (int i = 0; i < grammar.alphabet.size(); i++) {
            if (i != 0) {
                cout << ", ";
            }
            cout << grammar.alphabet[i];
        }
        cout << " }" << endl;
        yy_pop_state();
    }
}

<G_START_SYMBOL>{
    {string} ;
    ; {
        // Si pe asta il ignor complet
        yy_pop_state();
    }
}

<G_PRODUCTIONS>{
    & ; // ignor caracteru de concatenare
    {nonterminal} {
        grammar.nonterminal_count++;
    }
    [a-z0-9] {
        grammar.terminal_count++;
    }
    "->" {
        // ma ocup de partea din stanga sagetii productiei

        // Am explicat in readme logica conditiilor astea
        grammar.start_size = grammar.nonterminal_count + grammar.terminal_count;
        if (grammar.nonterminal_count == 0) {
            // nu avem neterminale in stanga -> Downgrade la GN
            grammar.type = min(GN, grammar.type);
        } else if (grammar.start_size > 1) {
            // mai mult de un simbol in stanga -> Downgrade la GDC
            grammar.type = min(GDC, grammar.type);
        }

        grammar.nonterminal_count = 0;
        grammar.terminal_count = 0;
        yy_push_state(G_PRODUCTIONS_END);
    }
}

<G_PRODUCTIONS_END>{
    & ; // ignor caracteru de concatenare
    {nonterminal} {
        grammar.nonterminal_count++;
        grammar.last_read = yytext; // tin minte ultimul simbol citit
        // pt a verifica daca este "e"
    }
    [a-z0-9] {
        // terminal
        grammar.terminal_count++;
        if (grammar.nonterminal_count >= 1) {
            // avem macar un neterminal in dreapta -> Downgrade la GIC
            grammar.type = min(GIC, grammar.type);
        }
        grammar.last_read = yytext;
    }
    "|" {
        int end_size = grammar.nonterminal_count + grammar.terminal_count;
        if (end_size < grammar.start_size && grammar.last_read != "e") {
            // partea dreapta mai mica decat stanga -> Downgrade la GN
            grammar.type = min(GN, grammar.type);
        }

        grammar.nonterminal_count = 0;
        grammar.terminal_count = 0;
        grammar.production_rules++;
    }
    ";" {
        // Ca mai sus, dar acum trecem la alta regula cu alt membru stanga, deci pop la starea actuala
        int end_size = grammar.nonterminal_count + grammar.terminal_count;
        if (end_size < grammar.start_size && grammar.last_read != "e") {
            // la fel ca mai sus, Downgrade la GN
            grammar.type = min(GN, grammar.type);
        }

        grammar.nonterminal_count = 0;
        grammar.terminal_count = 0;
        grammar.production_rules++;

        // Am si "G_PRODUCTIONS" si "G_PRODUCTIONS_END" pe stiva
        yy_pop_state();
        yy_pop_state();
    }
}

%%



int main(int argc, char* argv[]) {
    if (argc > 1) {
        if (!(yyin = fopen(argv[1], "r"))) {
            cout << "Fisierul " << argv[1] << " nu a putut fi deschis" << endl;
            return 1;
        }
    } else {
        cout << "Trebuie specificat un fisier de intrare" << endl;
        return 1;
    }
    yylex();
    return 0;
}