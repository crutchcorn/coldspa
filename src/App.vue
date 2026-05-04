<script setup>
import {ref} from "vue";

defineProps({
    hello: { type: String, default: '' },
    serverTime: { type: String, default: '' }
});

const count = ref(0);
function add() {
    count.value++;
}
</script>

<template>
    <div class="island">
        <h2>Hello, {{ hello }}!</h2>
        <p>Rendered server-side at: <code>{{ serverTime }}</code></p>
        <p>Hydrated client-side by Vue.</p>
        <button @click="add()">{{count}}</button>
    </div>
</template>

<style scoped>
.island {
    border: 2px solid #42b883;
    border-radius: 8px;
    padding: 1rem;
    background: #f5fbf8;
}
</style>
