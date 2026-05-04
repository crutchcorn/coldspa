import { useState } from 'react';
import './App.css';

export default function App({ hello = '', serverTime = '', header, footer, children }) {
    const [count, setCount] = useState(0);

    return (
        <div className="island">
            <header className="island__header">
                {header ?? <h2>Hello, {hello}!</h2>}
            </header>

            <main className="island__main">
                <p>Rendered server-side at: <code>{serverTime}</code></p>
                <p>Hydrated client-side by React.</p>
                <button type="button" onClick={() => setCount(c => c + 1)}>
                    Clicked {count} times
                </button>
                {children}
            </main>

            <footer className="island__footer">
                {footer ?? <small>(no footer slot supplied)</small>}
            </footer>
        </div>
    );
}
