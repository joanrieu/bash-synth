#!/bin/bash

printf "==> Components\n" >&2

printf " - (base)\n" >&2

cat <<END
#include <cmath>
#include <iostream>
#include <memory>
#include <vector>

using namespace std;

struct Component {
        std::string name;
        Component(const std::string& componentName): name(componentName) {}
        void check(const bool invalid, const char* port) { if (invalid) { std::cerr << "error: port " << port << " in " << name << " not connected" << std::endl; abort(); } }
        virtual void update() = 0;
};

END

(
for file in $(find -name "*.cmp")
do

        component=$(sed -re 's/[^[:alnum:]]//g' -e 's/...$//' <<<$file)
        printf " - %s\n" "$component" >&2

        # struct

        printf "struct %s: Component {\n" "$component"
        printf "\t%s(const std::string& componentName = \"%s\");\n" "$component" "$component"

        exec <$file
        while read io port && [[ "$io" != "" ]]
        do
                if [[ "$io" == "i" ]] || [[ "$io" == "o" ]]
                then
                        printf "\tstd::shared_ptr<float> port_%s_%s;\n" "$io" "$port"
                elif [[ "$io" == "m" ]]
                then
                        printf "\t%s;\n" "$port"
                else
                        printf "error: unknown port type \"%s\" in: %s %s\n" "$io" "$io" "$port" >&2
                fi
        done

        printf "\tvirtual void update();\n"
        printf "};\n\n"

        # init()

        printf "%s::%s(const std::string& componentName): Component(componentName) {\n" "$component" "$component"
        exec <$file
        while read io port && [[ "$io" != "" ]]
        do
                if [[ "$io" == "o" ]]
                then
                        printf "\tport_%s_%s.reset(new float);\n" "$io" "$port"
                fi
        done
        printf "}\n\n"

        # update()

        printf "void %s::update() {\n\n" "$component"
        exec <$file
        while read io port && [[ "$io" != "" ]]
        do
                printf "\tcheck(not port_%s_%s, \"%s\");\n" "$io" "$port" "$port"
                printf "\tfloat& %s(*port_%s_%s);\n" "$port" "$io" "$port"
        done
        printf "\n"
        while read line
        do
                printf "\t%s\n" "$line"
        done
        printf "\n}\n\n"

done
)

# graph

printf "==> Graph\n" >&2

printf "void setup(std::vector<Component*>& components) {\n"

# graph nodes

printf " - Nodes\n" >&2

while read type name && [[ "$type" != "" ]]
do
        printf "\t%s* component_%s = new %s(\"%s\");\n" "$type" "$name" "$type" "$name"
        printf "\tcomponents.push_back(component_%s);\n" "$name"
done

# graph links

printf " - Links\n" >&2

while read source oport operation dest iport
do
        if [[ "$operation" == ">" ]]
        then
                printf "\tcomponent_%s->port_i_%s = component_%s->port_o_%s;\n" "$dest" "$iport" "$source" "$oport"
        elif [[ "$operation" == "=" ]]
        then
                value="$dest"
                dest="$source"
                iport="$oport"
                printf "\tcomponent_%s->port_i_%s.reset(new float(%s));\n" "$dest" "$iport" "$value"
        else
                printf "error: unknown operation: \"%s\" in: %s %s %s %s %s\n" \
                        "$operation" "$source" "$oport" "$operation" "$dest" "$iport" >&2
                exit 1
        fi
done

printf "}\n\n"

printf "==> Main loop\n" >&2

# update order

cat <<END
int main() {

        std::vector<Component*> components;
        setup(components);

        while (true) {
                for (Component* const component: components) {
                        component->update();
                }
        }

}
END
