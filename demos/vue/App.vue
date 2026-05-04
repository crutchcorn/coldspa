<script setup>
import { ref } from 'vue';

defineProps({
    hello:      { type: String, default: '' },
    serverTime: { type: String, default: '' }
});

const count = ref(0);
function add() { count.value++; }
</script>

<template>
    <div class="island">
        <header class="island__header">
            <slot name="header">
                <h2>Hello, {{ hello }}!</h2>
            </slot>
        </header>

        <main class="island__main">
            <p>Rendered server-side at: <code>{{ serverTime }}</code></p>
            <p>Hydrated client-side by Vue.</p>
            <button type="button" @click="add">Clicked {{ count }} times</button>
            <slot />
        </main>

        <footer class="island__footer">
            <slot name="footer">
                <small>(no footer slot supplied)</small>
            </slot>
        </footer>
    </div>
</template>

<style scoped>
.island {
    border: 2px solid #42b883;
    border-radius: 8px;
    padding: 1rem;
    background: #f5fbf8;
}
.island__header { margin-bottom: 0.5rem; }
.island__footer { margin-top: 0.75rem; color: #555; }
</style>
