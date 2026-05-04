<!---
    cf_Slot custom tag.

    Captures its body as a named slot and registers it with the enclosing
    <cf_Island>. Must be nested inside a <cf_Island>.

    Usage:
        <cf_Island framework="#Vue#" path="./src/App.vue">
            Default slot content goes here directly...

            <cf_Slot name="header">
                <h1>Custom header</h1>
            </cf_Slot>

            <cf_Slot name="footer">
                <p>Custom footer</p>
            </cf_Slot>
        </cf_Island>

    Vue receives these via <slot name="header"/>; React receives them as props
    of the same name (e.g. props.header).

    Attributes:
        name  (string, required)  - slot name. Must be a valid identifier.
--->
<cfparam name="attributes.name" type="string">

<cfscript>
// Run on the END pass so generatedContent contains the rendered body.
if (thisTag.executionMode neq "end") {
    exit "exitTemplate";
}

if (!reFind("^[A-Za-z_][A-Za-z0-9_]*$", attributes.name)) {
    throw(
        type    = "Coldspa.InvalidSlotName",
        message = "<cf_Slot> name must be a valid identifier (letters, digits, underscore; must start with letter/underscore). Got: '#attributes.name#'."
    );
}

if (attributes.name == "default") {
    throw(
        type    = "Coldspa.InvalidSlotName",
        message = "<cf_Slot name=""default""> is reserved. Place default-slot content directly inside <cf_Island> instead."
    );
}

slotBody = trim(thisTag.generatedContent);
// Strip ourselves from the parent's body output -- we don't want our markup
// leaking into the default slot.
thisTag.generatedContent = "";

try {
    parent = getBaseTagData("CF_ISLAND");
} catch (any e) {
    throw(
        type    = "Coldspa.OrphanSlot",
        message = "<cf_Slot name=""#attributes.name#""> must be nested inside a <cf_Island>."
    );
}

if (!structKeyExists(parent, "namedSlots")) {
    parent.namedSlots = {};
}
parent.namedSlots[attributes.name] = slotBody;
</cfscript>
