return (
    <div className="categories-container">
        <h2>Категории</h2>
        <ul>
            {categories.map(category => (
                <li key={category.id}>
                    {category.name} <span>({category.bookCount} книг)</span>
                </li>
            ))}
        </ul>
    </div>
); 