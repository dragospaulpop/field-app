// TypeScript 6 checks side-effect imports: this tells it a .css import is fine
// (Metro and Uniwind handle the file; it exports nothing).
declare module '*.css';
